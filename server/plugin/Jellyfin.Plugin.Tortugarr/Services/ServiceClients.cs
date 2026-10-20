using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>A call to Sonarr/Radarr/Bazarr/qBittorrent that failed; becomes 502 upstream_failed.</summary>
public sealed class UpstreamException : Exception
{
    public UpstreamException(string service, string message)
        : base($"{service}: {message}")
    {
        Service = service;
    }

    public string Service { get; }
}

/// <summary>A service the route needs has no address/key; becomes 503 not_configured.</summary>
public sealed class NotConfiguredException : Exception
{
    public NotConfiguredException(string service)
        : base($"{service} is not configured in the Tortugarr plugin")
    {
    }
}

/// <summary>Sonarr / Radarr v3 API with the X-Api-Key header. Keys never leave this class.</summary>
public sealed class ArrClient
{
    private readonly HttpClient _http;
    private readonly string _base;
    private readonly string _key;

    public ArrClient(HttpClient http, string name, string baseUrl, string apiKey, string apiPath = "/api/v3")
    {
        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(apiKey))
        {
            throw new NotConfiguredException(name);
        }

        _http = http;
        Name = name;
        _base = baseUrl.TrimEnd('/') + apiPath;
        _key = apiKey;
    }

    public string Name { get; }

    public Task<JsonNode?> Get(string path, CancellationToken ct, int timeoutSeconds = 30) =>
        Send(HttpMethod.Get, path, null, ct, timeoutSeconds);

    public Task<JsonNode?> Post(string path, object body, CancellationToken ct, int timeoutSeconds = 30) =>
        Send(HttpMethod.Post, path, body, ct, timeoutSeconds);

    public Task<JsonNode?> Put(string path, object body, CancellationToken ct) => Send(HttpMethod.Put, path, body, ct, 30);

    public Task<JsonNode?> Delete(string path, CancellationToken ct) => Send(HttpMethod.Delete, path, null, ct, 30);

    private async Task<JsonNode?> Send(HttpMethod method, string path, object? body, CancellationToken ct, int timeoutSeconds)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(timeoutSeconds));
        using var req = new HttpRequestMessage(method, _base + path);
        req.Headers.Add("X-Api-Key", _key);
        if (body is not null)
        {
            req.Content = body is JsonNode node
                ? new StringContent(node.ToJsonString(), System.Text.Encoding.UTF8, "application/json")
                : JsonContent.Create(body);
        }

        HttpResponseMessage res;
        try
        {
            res = await _http.SendAsync(req, cts.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new UpstreamException(Name, $"no answer within {timeoutSeconds} s");
        }
        catch (HttpRequestException e)
        {
            throw new UpstreamException(Name, e.Message);
        }

        using (res)
        {
            var text = await res.Content.ReadAsStringAsync(cts.Token).ConfigureAwait(false);
            if (!res.IsSuccessStatusCode)
            {
                throw new UpstreamException(Name, $"HTTP {(int)res.StatusCode} {Trim(text)}");
            }

            return string.IsNullOrWhiteSpace(text) ? null : JsonNode.Parse(text);
        }
    }

    private static string Trim(string s) => s.Length > 300 ? s[..300] : s;
}

/// <summary>qBittorrent Web API (v2): login, torrent files, free space.</summary>
/// <summary>
/// Where Radarr or Sonarr sends torrents: the enabled qBittorrent client with the best
/// priority, as an address. The plugin follows it, so a download client moved in Radarr
/// (to a qBittorrent on the host, say) needs no change in the plugin's own settings.
/// The *arrs hide passwords in this list, so only the address comes from here.
/// </summary>
public static class ArrQbitAddress
{
    public static string? From(JsonNode? clients)
    {
        if (clients is not JsonArray list)
        {
            return null;
        }

        var best = list
            .Where(c => c is not null
                && string.Equals((string?)c["implementation"], "QBittorrent", StringComparison.OrdinalIgnoreCase)
                && ((bool?)c["enable"] ?? false))
            .OrderBy(c => (int?)c!["priority"] ?? 1)
            .FirstOrDefault();
        if (best?["fields"] is not JsonArray fields)
        {
            return null;
        }

        JsonNode? Field(string name) => fields.FirstOrDefault(f => (string?)f?["name"] == name)?["value"];
        var host = (string?)Field("host");
        if (string.IsNullOrWhiteSpace(host))
        {
            return null;
        }

        var port = (int?)Field("port") ?? 8080;
        var scheme = ((bool?)Field("useSsl") ?? false) ? "https" : "http";
        var urlBase = ((string?)Field("urlBase") ?? string.Empty).Trim('/');
        var url = $"{scheme}://{host.Trim()}:{port}";
        return urlBase.Length > 0 ? $"{url}/{urlBase}" : url;
    }
}

public sealed class QbitClient
{
    private readonly HttpClient _http;
    private readonly string _base;
    private readonly string _user;
    private readonly string _pass;

    public QbitClient(HttpClient http, string baseUrl, string user, string pass)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new NotConfiguredException("qBittorrent");
        }

        _http = http;
        _base = baseUrl.TrimEnd('/');
        _user = user;
        _pass = pass;
    }

    /// <summary>Files of a torrent, or null while its metadata is not there yet.</summary>
    public async Task<List<(string Name, long Size)>?> Files(string hash, CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        var res = await Request(HttpMethod.Get, $"/api/v2/torrents/files?hash={hash.ToLowerInvariant()}", null, cookie, ct).ConfigureAwait(false);
        if (res is not JsonArray arr || arr.Count == 0)
        {
            return null; // magnet still resolving
        }

        return arr.Select(f => ((string?)f?["name"] ?? string.Empty, (long?)f?["size"] ?? 0)).ToList();
    }

    /// <summary>Adds a magnet link or torrent URL with a category and save path.</summary>
    public async Task Add(string url, string category, string savePath, CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        var form = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["urls"] = url, ["category"] = category, ["savepath"] = savePath, ["autoTMM"] = "false",
        });
        await Request(HttpMethod.Post, "/api/v2/torrents/add", form, cookie, ct).ConfigureAwait(false);
    }

    /// <summary>Torrents in a category (newest first).</summary>
    public async Task<JsonArray> List(string category, CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        return await Request(HttpMethod.Get, $"/api/v2/torrents/info?category={Uri.EscapeDataString(category)}&sort=added_on&reverse=true", null, cookie, ct)
            .ConfigureAwait(false) as JsonArray ?? new JsonArray();
    }

    /// <summary>Every torrent, whatever its category.</summary>
    public async Task<JsonArray> ListAll(CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        return await Request(HttpMethod.Get, "/api/v2/torrents/info", null, cookie, ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
    }

    public async Task Delete(string hash, bool deleteFiles, CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        var form = new FormUrlEncodedContent(new Dictionary<string, string> { ["hashes"] = hash.ToLowerInvariant(), ["deleteFiles"] = deleteFiles ? "true" : "false" });
        await Request(HttpMethod.Post, "/api/v2/torrents/delete", form, cookie, ct).ConfigureAwait(false);
    }

    public async Task<long?> FreeSpace(CancellationToken ct)
    {
        var cookie = await Login(ct).ConfigureAwait(false);
        var res = await Request(HttpMethod.Get, "/api/v2/sync/maindata", null, cookie, ct).ConfigureAwait(false);
        return (long?)res?["server_state"]?["free_space_on_disk"];
    }

    private async Task<string> Login(CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, _base + "/api/v2/auth/login")
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string> { ["username"] = _user, ["password"] = _pass }),
        };
        req.Headers.Referrer = new Uri(_base);
        using var res = await SendRaw(req, ct).ConfigureAwait(false);
        // qBittorrent 4 answers "Ok.", qBittorrent 5 an empty 204; both set the session cookie.
        var cookie = res.Headers.TryGetValues("Set-Cookie", out var v) ? v.FirstOrDefault()?.Split(';')[0] : null;
        if (!res.IsSuccessStatusCode || cookie is null)
        {
            throw new UpstreamException("qBittorrent", $"login refused (HTTP {(int)res.StatusCode})");
        }

        return cookie;
    }

    private async Task<JsonNode?> Request(HttpMethod method, string path, HttpContent? content, string cookie, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(method, _base + path) { Content = content };
        req.Headers.Add("Cookie", cookie);
        req.Headers.Referrer = new Uri(_base);
        using var res = await SendRaw(req, ct).ConfigureAwait(false);
        var text = await res.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        if (res.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }

        if (!res.IsSuccessStatusCode)
        {
            throw new UpstreamException("qBittorrent", $"HTTP {(int)res.StatusCode}");
        }

        return string.IsNullOrWhiteSpace(text) ? null : JsonNode.Parse(text);
    }

    private async Task<HttpResponseMessage> SendRaw(HttpRequestMessage req, CancellationToken ct)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(30));
        try
        {
            return await _http.SendAsync(req, cts.Token).ConfigureAwait(false);
        }
        catch (Exception e) when (e is HttpRequestException or OperationCanceledException && !ct.IsCancellationRequested)
        {
            throw new UpstreamException("qBittorrent", e.Message);
        }
    }
}

/// <summary>Bazarr API: manual subtitle search and download, with the X-API-KEY header.</summary>
public sealed class BazarrClient
{
    private readonly HttpClient _http;
    private readonly string _base;
    private readonly string _key;

    public BazarrClient(HttpClient http, string baseUrl, string apiKey)
    {
        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(apiKey))
        {
            throw new NotConfiguredException("Bazarr");
        }

        _http = http;
        _base = baseUrl.TrimEnd('/') + "/api";
        _key = apiKey;
    }

    public async Task<JsonNode?> Get(string path, CancellationToken ct, int timeoutSeconds = 120)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, _base + path);
        return await Send(req, ct, timeoutSeconds).ConfigureAwait(false);
    }

    public async Task PatchForm(string path, Dictionary<string, string> form, CancellationToken ct, int timeoutSeconds = 300)
    {
        using var req = new HttpRequestMessage(HttpMethod.Patch, _base + path) { Content = new FormUrlEncodedContent(form) };
        await Send(req, ct, timeoutSeconds).ConfigureAwait(false);
    }

    public async Task PostForm(string path, Dictionary<string, string> form, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, _base + path) { Content = new FormUrlEncodedContent(form) };
        await Send(req, ct, 120).ConfigureAwait(false);
    }

    private async Task<JsonNode?> Send(HttpRequestMessage req, CancellationToken ct, int timeoutSeconds)
    {
        req.Headers.Add("X-API-KEY", _key);
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(TimeSpan.FromSeconds(timeoutSeconds));
        HttpResponseMessage res;
        try
        {
            res = await _http.SendAsync(req, cts.Token).ConfigureAwait(false);
        }
        catch (Exception e) when (e is HttpRequestException or OperationCanceledException && !ct.IsCancellationRequested)
        {
            throw new UpstreamException("Bazarr", e.Message);
        }

        using (res)
        {
            var text = await res.Content.ReadAsStringAsync(cts.Token).ConfigureAwait(false);
            if (!res.IsSuccessStatusCode)
            {
                throw new UpstreamException("Bazarr", $"HTTP {(int)res.StatusCode}");
            }

            try
            {
                return string.IsNullOrWhiteSpace(text) ? null : JsonNode.Parse(text);
            }
            catch (JsonException)
            {
                return null;
            }
        }
    }
}
