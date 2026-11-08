using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// What Tortugarr asks of a torrent client (2026-11-08: no longer tied to qBittorrent). Torrent
/// lists come back in qBittorrent's shape - hash, name, state (downloading, stalledDL, metaDL,
/// queuedDL, stoppedDL, uploading, stalledUP, stoppedUP, checkingDL, checkingUP, error),
/// progress 0..1, category, size, amount_left, completion_on, save_path, content_path, dlspeed,
/// num_seeds, force_start - so the watchdog, the video check and the rest work the same for all.
/// </summary>
public interface ITorrentClient
{
    string Name { get; }

    /// <summary>Only qBittorrent can be closed so something restarts it (the Windows keepalive).</summary>
    bool CanShutdown { get; }

    Task<List<(string Name, long Size)>?> Files(string hash, CancellationToken ct);

    Task Add(string url, string category, string savePath, CancellationToken ct);

    Task AddFile(byte[] torrent, string category, string savePath, CancellationToken ct);

    Task<JsonArray> List(string category, CancellationToken ct);

    Task<JsonArray> ListAll(CancellationToken ct);

    Task Delete(string hash, bool deleteFiles, CancellationToken ct);

    Task Recheck(IEnumerable<string> hashes, CancellationToken ct);

    Task Reannounce(IEnumerable<string> hashes, CancellationToken ct);

    Task Stop(IEnumerable<string> hashes, CancellationToken ct);

    Task Start(IEnumerable<string> hashes, CancellationToken ct);

    Task Shutdown(CancellationToken ct);

    /// <summary>Points a category at a folder (qBittorrent); the others take the folder per torrent.</summary>
    Task EditCategory(string category, string savePath, CancellationToken ct);

    Task<long?> FreeSpace(CancellationToken ct);

    Task<string> Version(CancellationToken ct);
}

/// <summary>The torrent client the settings name.</summary>
public static class TorrentClient
{
    public static readonly string[] Kinds = { "qbittorrent", "transmission", "deluge" };

    public static bool IsTorrent(string? kind) => Kinds.Contains(kind);

    public static ITorrentClient Create(HttpClient http, string kind, string url, string user, string pass) => kind switch
    {
        "qbittorrent" => new QbitClient(http, url, user, pass),
        "transmission" => new TransmissionClient(http, url, user, pass),
        "deluge" => new DelugeClient(http, url, pass),
        _ => throw new NotConfiguredException("a torrent client"),
    };

    internal static long Unix(DateTimeOffset? t) => t is null ? -1 : t.Value.ToUnixTimeSeconds();

    /// <summary>A number from any JSON number (int, long or double), 0 when missing or not a number.</summary>
    internal static double D(JsonNode? n) =>
        n is JsonValue v && double.TryParse(v.ToJsonString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var d) ? d : 0;

    internal static long L(JsonNode? n) => (long)D(n);
}

/// <summary>Transmission's RPC (/transmission/rpc, X-Transmission-Session-Id handshake, basic auth).</summary>
public sealed class TransmissionClient : ITorrentClient
{
    private static readonly string[] Fields =
    {
        "hashString", "name", "status", "percentDone", "leftUntilDone", "sizeWhenDone", "totalSize", "doneDate",
        "addedDate", "labels", "downloadDir", "rateDownload", "peersSendingToUs", "error", "metadataPercentComplete",
    };

    private readonly HttpClient _http;
    private readonly string _rpc;
    private readonly string? _auth;
    private string _session = string.Empty;

    public TransmissionClient(HttpClient http, string baseUrl, string user, string pass)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new NotConfiguredException("Transmission");
        }

        _http = http;
        var b = baseUrl.TrimEnd('/');
        _rpc = b.EndsWith("/rpc", StringComparison.Ordinal) ? b : b.EndsWith("/transmission", StringComparison.Ordinal) ? b + "/rpc" : b + "/transmission/rpc";
        _auth = string.IsNullOrEmpty(user) ? null : Convert.ToBase64String(Encoding.UTF8.GetBytes($"{user}:{pass}"));
    }

    public string Name => "Transmission";

    public bool CanShutdown => false;

    internal async Task<JsonNode?> Call(string method, JsonObject? args, CancellationToken ct)
    {
        for (var attempt = 0; attempt < 2; attempt++)
        {
            using var req = new HttpRequestMessage(HttpMethod.Post, _rpc)
            {
                Content = new StringContent(new JsonObject { ["method"] = method, ["arguments"] = args?.DeepClone() ?? new JsonObject() }.ToJsonString(), Encoding.UTF8, "application/json"),
            };
            req.Headers.TryAddWithoutValidation("X-Transmission-Session-Id", _session);
            if (_auth is not null)
            {
                req.Headers.Authorization = new AuthenticationHeaderValue("Basic", _auth);
            }

            using var res = await _http.SendAsync(req, ct).ConfigureAwait(false);
            if (res.StatusCode == HttpStatusCode.Conflict && res.Headers.TryGetValues("X-Transmission-Session-Id", out var ids))
            {
                _session = ids.First(); // the handshake: ask again with the session id
                continue;
            }

            if (!res.IsSuccessStatusCode)
            {
                throw new UpstreamException("Transmission", $"HTTP {(int)res.StatusCode}");
            }

            var body = JsonNode.Parse(await res.Content.ReadAsStringAsync(ct).ConfigureAwait(false));
            var result = (string?)body?["result"];
            if (result != "success")
            {
                throw new UpstreamException("Transmission", result ?? "no answer");
            }

            return body?["arguments"];
        }

        throw new UpstreamException("Transmission", "no session id");
    }

    private static JsonArray Ids(IEnumerable<string> hashes) => new(hashes.Select(h => (JsonNode?)JsonValue.Create(h.ToLowerInvariant())).ToArray());

    /// <summary>One Transmission torrent in qBittorrent's shape.</summary>
    internal static JsonObject Map(JsonNode t)
    {
        var status = (int)TorrentClient.L(t["status"]);
        var percent = TorrentClient.D(t["percentDone"]);
        var left = TorrentClient.L(t["leftUntilDone"]);
        var meta = (t["metadataPercentComplete"] is null ? 1 : TorrentClient.D(t["metadataPercentComplete"])) < 1;
        var done = percent >= 1;
        var rate = TorrentClient.L(t["rateDownload"]);
        var error = (int)TorrentClient.L(t["error"]);
        var state = error is 3 ? "error" : status switch
        {
            0 => done ? "stoppedUP" : "stoppedDL",
            1 or 2 => done ? "checkingUP" : "checkingDL",
            3 => meta ? "metaDL" : "queuedDL",
            4 => meta ? "metaDL" : rate > 0 ? "downloading" : "stalledDL",
            5 => "queuedUP",
            6 => "uploading",
            _ => "unknown",
        };
        var dir = ((string?)t["downloadDir"] ?? string.Empty).TrimEnd('/');
        var name = (string?)t["name"] ?? string.Empty;
        var labels = t["labels"] as JsonArray;
        var category = (string?)labels?.FirstOrDefault() ?? Path.GetFileName(dir);
        var doneDate = TorrentClient.L(t["doneDate"]);
        return new JsonObject
        {
            ["hash"] = ((string?)t["hashString"] ?? string.Empty).ToLowerInvariant(),
            ["name"] = name,
            ["state"] = state,
            ["progress"] = percent,
            ["category"] = category,
            ["size"] = TorrentClient.L(t["sizeWhenDone"]),
            ["total_size"] = TorrentClient.L(t["totalSize"]),
            ["amount_left"] = meta ? -1 : left,
            ["completion_on"] = doneDate > 0 ? doneDate : -1,
            ["added_on"] = TorrentClient.L(t["addedDate"]),
            ["save_path"] = dir,
            ["content_path"] = dir.Length > 0 ? $"{dir}/{name}" : name,
            ["dlspeed"] = rate,
            ["num_seeds"] = (int)TorrentClient.L(t["peersSendingToUs"]),
            ["force_start"] = false,
        };
    }

    public async Task<JsonArray> ListAll(CancellationToken ct)
    {
        var res = await Call("torrent-get", new JsonObject { ["fields"] = new JsonArray(Fields.Select(f => (JsonNode?)JsonValue.Create(f)).ToArray()) }, ct).ConfigureAwait(false);
        return new JsonArray((res?["torrents"] as JsonArray ?? new JsonArray()).Where(t => t is not null).Select(t => (JsonNode?)Map(t!)).ToArray());
    }

    public async Task<JsonArray> List(string category, CancellationToken ct)
    {
        var all = await ListAll(ct).ConfigureAwait(false);
        return new JsonArray(all.Where(t => string.Equals((string?)t?["category"], category, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(t => (long?)t?["added_on"] ?? 0).Select(t => t!.DeepClone()).ToArray());
    }

    public async Task<List<(string Name, long Size)>?> Files(string hash, CancellationToken ct)
    {
        var res = await Call("torrent-get", new JsonObject { ["ids"] = Ids(new[] { hash }), ["fields"] = new JsonArray("files", "metadataPercentComplete") }, ct).ConfigureAwait(false);
        var t = (res?["torrents"] as JsonArray)?.FirstOrDefault();
        var files = t?["files"] as JsonArray;
        if (t is null || files is null || files.Count == 0 || (t["metadataPercentComplete"] is null ? 1 : TorrentClient.D(t["metadataPercentComplete"])) < 1)
        {
            return null;
        }

        return files.Select(f => ((string?)f?["name"] ?? string.Empty, (long?)f?["length"] ?? 0)).ToList();
    }

    public Task Add(string url, string category, string savePath, CancellationToken ct) =>
        Call("torrent-add", new JsonObject { ["filename"] = url, ["download-dir"] = savePath, ["labels"] = new JsonArray(category) }, ct);

    public Task AddFile(byte[] torrent, string category, string savePath, CancellationToken ct) =>
        Call("torrent-add", new JsonObject { ["metainfo"] = Convert.ToBase64String(torrent), ["download-dir"] = savePath, ["labels"] = new JsonArray(category) }, ct);

    public Task Delete(string hash, bool deleteFiles, CancellationToken ct) =>
        Call("torrent-remove", new JsonObject { ["ids"] = Ids(new[] { hash }), ["delete-local-data"] = deleteFiles }, ct);

    public Task Recheck(IEnumerable<string> hashes, CancellationToken ct) => Call("torrent-verify", new JsonObject { ["ids"] = Ids(hashes) }, ct);

    public Task Reannounce(IEnumerable<string> hashes, CancellationToken ct) => Call("torrent-reannounce", new JsonObject { ["ids"] = Ids(hashes) }, ct);

    public Task Stop(IEnumerable<string> hashes, CancellationToken ct) => Call("torrent-stop", new JsonObject { ["ids"] = Ids(hashes) }, ct);

    public Task Start(IEnumerable<string> hashes, CancellationToken ct) => Call("torrent-start", new JsonObject { ["ids"] = Ids(hashes) }, ct);

    public Task Shutdown(CancellationToken ct) => throw new NotSupportedException("Transmission is not restarted by Tortugarr");

    public Task EditCategory(string category, string savePath, CancellationToken ct) => Task.CompletedTask;

    public async Task<long?> FreeSpace(CancellationToken ct)
    {
        var session = await Call("session-get", null, ct).ConfigureAwait(false);
        var dir = (string?)session?["download-dir"];
        if (string.IsNullOrEmpty(dir))
        {
            return null;
        }

        // The download folder may not exist before the first download: measure the nearest one that does.
        for (var path = dir; !string.IsNullOrEmpty(path); path = Path.GetDirectoryName(path.TrimEnd('/')))
        {
            try
            {
                var res = await Call("free-space", new JsonObject { ["path"] = path }, ct).ConfigureAwait(false);
                return TorrentClient.L(res?["size-bytes"]);
            }
            catch (UpstreamException) when (path != "/")
            {
            }
        }

        return null;
    }

    public async Task<string> Version(CancellationToken ct) =>
        (string?)(await Call("session-get", null, ct).ConfigureAwait(false))?["version"] ?? string.Empty;
}

/// <summary>Deluge's Web UI JSON-RPC (/json; auth.login with the Web UI password, cookie session).</summary>
public sealed class DelugeClient : ITorrentClient
{
    private static readonly string[] Fields =
    {
        "hash", "name", "state", "progress", "total_wanted", "total_done", "total_size", "label", "save_path",
        "download_payload_rate", "completed_time", "time_added", "num_seeds", "is_finished", "files",
    };

    private readonly HttpClient _http;
    private readonly string _json;
    private readonly string _pass;
    private string _cookie = string.Empty;
    private int _id;

    public DelugeClient(HttpClient http, string baseUrl, string pass)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new NotConfiguredException("Deluge");
        }

        _http = http;
        var b = baseUrl.TrimEnd('/');
        _json = b.EndsWith("/json", StringComparison.Ordinal) ? b : b + "/json";
        _pass = string.IsNullOrEmpty(pass) ? "deluge" : pass;
    }

    public string Name => "Deluge";

    public bool CanShutdown => false;

    private async Task<JsonNode?> Raw(string method, JsonArray args, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, _json)
        {
            Content = new StringContent(new JsonObject { ["method"] = method, ["params"] = args, ["id"] = Interlocked.Increment(ref _id) }.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        if (_cookie.Length > 0)
        {
            req.Headers.Add("Cookie", _cookie);
        }

        using var res = await _http.SendAsync(req, ct).ConfigureAwait(false);
        if (res.Headers.TryGetValues("Set-Cookie", out var c) && c.FirstOrDefault() is { } cookie)
        {
            _cookie = cookie.Split(';')[0];
        }

        if (!res.IsSuccessStatusCode)
        {
            throw new UpstreamException("Deluge", $"HTTP {(int)res.StatusCode}");
        }

        var body = JsonNode.Parse(await res.Content.ReadAsStringAsync(ct).ConfigureAwait(false));
        if (body?["error"] is JsonObject err)
        {
            throw new UpstreamException("Deluge", (string?)err["message"] ?? "error");
        }

        return body?["result"];
    }

    /// <summary>Logs in, and connects the Web UI to its daemon when it is not yet.</summary>
    internal async Task<JsonNode?> Call(string method, JsonArray args, CancellationToken ct)
    {
        if (_cookie.Length == 0)
        {
            if ((bool?)await Raw("auth.login", new JsonArray(_pass), ct).ConfigureAwait(false) != true)
            {
                throw new UpstreamException("Deluge", "login refused");
            }

            if ((bool?)await Raw("web.connected", new JsonArray(), ct).ConfigureAwait(false) != true
                && await Raw("web.get_hosts", new JsonArray(), ct).ConfigureAwait(false) is JsonArray { Count: > 0 } hosts
                && (string?)(hosts[0] as JsonArray)?[0] is { } hostId)
            {
                await Raw("web.connect", new JsonArray(hostId), ct).ConfigureAwait(false);
            }
        }

        return await Raw(method, args, ct).ConfigureAwait(false);
    }

    private static JsonArray Ids(IEnumerable<string> hashes) => new(hashes.Select(h => (JsonNode?)JsonValue.Create(h.ToLowerInvariant())).ToArray());

    /// <summary>One Deluge torrent in qBittorrent's shape.</summary>
    internal static JsonObject Map(string hash, JsonNode t)
    {
        var state = (string?)t["state"] ?? string.Empty;
        var progress = TorrentClient.D(t["progress"]) / 100.0;
        var wanted = TorrentClient.L(t["total_wanted"]);
        var doneBytes = TorrentClient.L(t["total_done"]);
        var finished = (bool?)t["is_finished"] ?? progress >= 1;
        var rate = TorrentClient.L(t["download_payload_rate"]);
        var noMeta = wanted == 0 && !finished && state is "Downloading" or "Queued";
        var mapped = state switch
        {
            "Downloading" => noMeta ? "metaDL" : rate > 0 ? "downloading" : "stalledDL",
            "Seeding" => "uploading",
            "Paused" => finished ? "stoppedUP" : "stoppedDL",
            "Checking" => finished ? "checkingUP" : "checkingDL",
            "Queued" => finished ? "queuedUP" : noMeta ? "metaDL" : "queuedDL",
            "Error" => "error",
            "Moving" => "moving",
            "Allocating" => "allocating",
            _ => "unknown",
        };
        var dir = ((string?)t["save_path"] ?? string.Empty).TrimEnd('/');
        var name = (string?)t["name"] ?? string.Empty;
        var completed = TorrentClient.L(t["completed_time"]);
        return new JsonObject
        {
            ["hash"] = hash.ToLowerInvariant(),
            ["name"] = name,
            ["state"] = mapped,
            ["progress"] = progress,
            ["category"] = (string?)t["label"] ?? string.Empty,
            ["size"] = wanted,
            ["total_size"] = TorrentClient.L(t["total_size"]),
            ["amount_left"] = noMeta ? -1 : Math.Max(0, wanted - doneBytes),
            ["completion_on"] = finished && completed > 0 ? completed : -1,
            ["added_on"] = TorrentClient.L(t["time_added"]),
            ["save_path"] = dir,
            ["content_path"] = dir.Length > 0 ? $"{dir}/{name}" : name,
            ["dlspeed"] = rate,
            ["num_seeds"] = (int)TorrentClient.L(t["num_seeds"]),
            ["force_start"] = false,
        };
    }

    public async Task<JsonArray> ListAll(CancellationToken ct)
    {
        var res = await Call("core.get_torrents_status", new JsonArray(new JsonObject(), new JsonArray(Fields.Where(f => f != "files").Select(f => (JsonNode?)JsonValue.Create(f)).ToArray())), ct).ConfigureAwait(false) as JsonObject;
        return new JsonArray((res ?? new JsonObject()).Where(kv => kv.Value is not null).Select(kv => (JsonNode?)Map(kv.Key, kv.Value!)).ToArray());
    }

    public async Task<JsonArray> List(string category, CancellationToken ct)
    {
        var all = await ListAll(ct).ConfigureAwait(false);
        return new JsonArray(all.Where(t => string.Equals((string?)t?["category"], category, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(t => (long?)t?["added_on"] ?? 0).Select(t => t!.DeepClone()).ToArray());
    }

    public async Task<List<(string Name, long Size)>?> Files(string hash, CancellationToken ct)
    {
        var t = await Call("core.get_torrent_status", new JsonArray(hash.ToLowerInvariant(), new JsonArray("files", "total_wanted")), ct).ConfigureAwait(false);
        var files = t?["files"] as JsonArray;
        if (files is null || files.Count == 0)
        {
            return null;
        }

        return files.Select(f => ((string?)f?["path"] ?? string.Empty, (long?)f?["size"] ?? 0)).ToList();
    }

    private static JsonObject Options(string savePath) => new() { ["download_location"] = savePath };

    private async Task Label(string? hash, string category, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(hash) || string.IsNullOrEmpty(category))
        {
            return;
        }

        var label = category.ToLowerInvariant();
        try
        {
            try
            {
                await Call("label.add", new JsonArray(label), ct).ConfigureAwait(false);
            }
            catch (UpstreamException e) when (e.Message.Contains("Unknown method", StringComparison.OrdinalIgnoreCase))
            {
                // A fresh Deluge has the Label plugin switched off; Radarr and Sonarr switch it on too.
                await Call("core.enable_plugin", new JsonArray("Label"), ct).ConfigureAwait(false);
                await Task.Delay(1000, ct).ConfigureAwait(false);
                await Call("label.add", new JsonArray(label), ct).ConfigureAwait(false);
            }
        }
        catch (UpstreamException)
        {
            // the label exists already
        }

        try
        {
            await Call("label.set_torrent", new JsonArray(hash, label), ct).ConfigureAwait(false);
        }
        catch (UpstreamException)
        {
            // no Label plugin at all: the torrent is still added, only without a category
        }
    }

    public async Task Add(string url, string category, string savePath, CancellationToken ct)
    {
        var method = url.StartsWith("magnet:", StringComparison.OrdinalIgnoreCase) ? "core.add_torrent_magnet" : "core.add_torrent_url";
        var hash = (string?)await Call(method, new JsonArray(url, Options(savePath)), ct).ConfigureAwait(false);
        await Label(hash, category, ct).ConfigureAwait(false);
    }

    public async Task AddFile(byte[] torrent, string category, string savePath, CancellationToken ct)
    {
        var hash = (string?)await Call("core.add_torrent_file", new JsonArray("release.torrent", Convert.ToBase64String(torrent), Options(savePath)), ct).ConfigureAwait(false);
        await Label(hash, category, ct).ConfigureAwait(false);
    }

    public Task Delete(string hash, bool deleteFiles, CancellationToken ct) =>
        Call("core.remove_torrent", new JsonArray(hash.ToLowerInvariant(), deleteFiles), ct);

    public Task Recheck(IEnumerable<string> hashes, CancellationToken ct) => Call("core.force_recheck", new JsonArray(Ids(hashes)), ct);

    public Task Reannounce(IEnumerable<string> hashes, CancellationToken ct) => Call("core.force_reannounce", new JsonArray(Ids(hashes)), ct);

    public Task Stop(IEnumerable<string> hashes, CancellationToken ct) => Call("core.pause_torrents", new JsonArray(Ids(hashes)), ct);

    public Task Start(IEnumerable<string> hashes, CancellationToken ct) => Call("core.resume_torrents", new JsonArray(Ids(hashes)), ct);

    public Task Shutdown(CancellationToken ct) => throw new NotSupportedException("Deluge is not restarted by Tortugarr");

    public Task EditCategory(string category, string savePath, CancellationToken ct) => Task.CompletedTask;

    public async Task<long?> FreeSpace(CancellationToken ct) => (long?)await Call("core.get_free_space", new JsonArray(), ct).ConfigureAwait(false);

    public async Task<string> Version(CancellationToken ct) => (string?)await Call("daemon.get_version", new JsonArray(), ct).ConfigureAwait(false) ?? string.Empty;
}
