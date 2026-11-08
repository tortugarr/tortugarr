using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Phone notifications without Firebase (G, 2026-11-08), through the ntfy server in the stack:
/// "ready to watch" to whoever downloaded or requested a title (one message per season for
/// episodes), and the problems Tortugarr dealt with (stuck, fake, wrong downloads) to
/// administrators. Each user has a secret random topic they subscribe to in the ntfy app.
/// </summary>
public sealed class NotifyService
{
    internal static readonly TimeSpan GrabMemory = TimeSpan.FromDays(30);
    internal static readonly TimeSpan EpisodeBatch = TimeSpan.FromMinutes(5);
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    private readonly IHttpClientFactory _httpFactory;
    private readonly ILogger<NotifyService> _log;
    private readonly object _gate = new();
    private readonly string? _ledgerPath;
    private readonly Dictionary<string, EpisodeBatchState> _batches = new(StringComparer.Ordinal);

    public NotifyService(IHttpClientFactory httpFactory, ILogger<NotifyService> log)
    {
        _httpFactory = httpFactory;
        _log = log;
        _ledgerPath = Plugin.Instance is { } p ? Path.Combine(p.DataFolderPath, "notify-grabs.json") : null;
    }

    private static PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new PluginConfiguration();

    public bool Enabled => !string.IsNullOrWhiteSpace(Cfg.NtfyUrl) && !string.IsNullOrWhiteSpace(Cfg.NtfyPublicUrl);

    // ------------------------------------------------------------------ who asked for it

    /// <summary>Remembers who started a download, so its "ready" goes to them.</summary>
    public void RememberGrab(string? downloadId, Guid userId)
    {
        if (string.IsNullOrEmpty(downloadId) || userId == Guid.Empty || _ledgerPath is null)
        {
            return;
        }

        lock (_gate)
        {
            var now = DateTimeOffset.UtcNow;
            var all = LoadLedger().Where(g => now - g.At < GrabMemory && !string.Equals(g.DownloadId, downloadId, StringComparison.OrdinalIgnoreCase)).ToList();
            all.Add(new GrabOwner { DownloadId = downloadId, UserId = userId.ToString("N"), At = now });
            try
            {
                File.WriteAllText(_ledgerPath, JsonSerializer.Serialize(all.TakeLast(2000), Options));
            }
            catch (Exception e)
            {
                _log.LogDebug(e, "Tortugarr: notify ledger not written");
            }
        }
    }

    public Guid? WhoGrabbed(string? downloadId)
    {
        if (string.IsNullOrEmpty(downloadId))
        {
            return null;
        }

        lock (_gate)
        {
            var hit = LoadLedger().LastOrDefault(g => string.Equals(g.DownloadId, downloadId, StringComparison.OrdinalIgnoreCase));
            return hit is not null && Guid.TryParse(hit.UserId, out var id) ? id : null;
        }
    }

    private List<GrabOwner> LoadLedger()
    {
        try
        {
            return _ledgerPath is not null && File.Exists(_ledgerPath)
                ? JsonSerializer.Deserialize<List<GrabOwner>>(File.ReadAllText(_ledgerPath), Options) ?? new()
                : new();
        }
        catch (Exception e)
        {
            _log.LogDebug(e, "Tortugarr: notify ledger unreadable");
            return new();
        }
    }

    // ------------------------------------------------------------------ users' settings

    /// <summary>The user's settings, with a fresh secret topic the first time.</summary>
    public NotifyUser Me(Guid userId, bool isAdmin)
    {
        var plugin = Plugin.Instance ?? throw new NotConfiguredException("the plugin is not loaded");
        if (userId == Guid.Empty)
        {
            throw new ArgumentException("notifications belong to a user; an API key has none");
        }

        lock (_gate)
        {
            var key = userId.ToString("N");
            var me = plugin.Configuration.NotifyUsers.FirstOrDefault(u => u.UserId == key);
            if (me is not null)
            {
                return me;
            }

            me = new NotifyUser { UserId = key, Topic = NewTopic(), Ready = true, Problems = isAdmin, Everything = false };
            plugin.Configuration.NotifyUsers = plugin.Configuration.NotifyUsers.Append(me).ToArray();
            plugin.SaveConfiguration();
            return me;
        }
    }

    public NotifyUser Update(Guid userId, bool? ready, bool? problems, bool? everything, bool isAdmin)
    {
        var me = Me(userId, isAdmin);
        lock (_gate)
        {
            me.Ready = ready ?? me.Ready;
            me.Problems = isAdmin && (problems ?? me.Problems);
            me.Everything = isAdmin && (everything ?? me.Everything);
            Plugin.Instance?.SaveConfiguration();
            return me;
        }
    }

    /// <summary>"tortugarr-" and 26 random base32 characters: unguessable.</summary>
    internal static string NewTopic()
    {
        const string alphabet = "abcdefghijklmnopqrstuvwxyz234567";
        var bytes = RandomNumberGenerator.GetBytes(26);
        var sb = new StringBuilder("tortugarr-");
        foreach (var b in bytes)
        {
            sb.Append(alphabet[b & 31]);
        }

        return sb.ToString();
    }

    /// <summary>What the app shows: where to subscribe.</summary>
    public object Describe(NotifyUser me, bool isAdmin)
    {
        var pub = Cfg.NtfyPublicUrl.TrimEnd('/');
        return new
        {
            available = Enabled,
            server = pub,
            topic = me.Topic,
            subscribeUrl = Enabled ? $"{pub}/{me.Topic}" : null,
            appUrl = Enabled ? AppLink(pub, me.Topic) : null,
            ready = me.Ready,
            problems = isAdmin && me.Problems,
            everything = isAdmin && me.Everything,
            isAdmin,
        };
    }

    /// <summary>ntfy's own link that opens the app with the subscription filled in.</summary>
    internal static string AppLink(string publicUrl, string topic)
    {
        var uri = new Uri(publicUrl);
        var hostPort = uri.IsDefaultPort ? uri.Host : $"{uri.Host}:{uri.Port}";
        return uri.Scheme == "https" ? $"ntfy://{hostPort}/{topic}" : $"ntfy://{hostPort}/{topic}?secure=false";
    }

    // ------------------------------------------------------------------ sending

    public async Task<bool> SendAsync(string topic, string title, string message, string tags, int priority = 3, CancellationToken ct = default)
    {
        if (!Enabled || string.IsNullOrEmpty(topic))
        {
            return false;
        }

        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Post, $"{Cfg.NtfyUrl.TrimEnd('/')}/{topic}")
            {
                Content = new StringContent(message, Encoding.UTF8, "text/plain"),
            };
            // ntfy reads non-ASCII header values as RFC 2047; plain titles go as they are.
            req.Headers.TryAddWithoutValidation("Title", HeaderSafe(title));
            req.Headers.TryAddWithoutValidation("Tags", tags);
            req.Headers.TryAddWithoutValidation("Priority", priority.ToString(System.Globalization.CultureInfo.InvariantCulture));
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(10));
            using var res = await _httpFactory.CreateClient("tortugarr").SendAsync(req, cts.Token).ConfigureAwait(false);
            return res.IsSuccessStatusCode;
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _log.LogWarning("Tortugarr: notification not sent: {Message}", e.Message);
            return false;
        }
    }

    internal static string HeaderSafe(string s) =>
        s.All(c => c >= 32 && c < 127) ? s : "=?UTF-8?B?" + Convert.ToBase64String(Encoding.UTF8.GetBytes(s)) + "?=";

    /// <summary>The topics a "ready" for these users goes to: theirs, plus admins who want everything.</summary>
    internal static List<string> ReadyTopics(IEnumerable<NotifyUser> all, IEnumerable<Guid> owners)
    {
        var keys = owners.Select(o => o.ToString("N")).ToHashSet();
        return all.Where(u => !string.IsNullOrEmpty(u.Topic) && u.Ready && (keys.Contains(u.UserId) || u.Everything))
            .Select(u => u.Topic).Distinct().ToList();
    }

    public async Task ReadyAsync(IEnumerable<Guid> owners, string title, string message)
    {
        foreach (var topic in ReadyTopics(Cfg.NotifyUsers, owners))
        {
            await SendAsync(topic, title, message, "tv,white_check_mark").ConfigureAwait(false);
        }
    }

    /// <summary>A problem Tortugarr dealt with, to administrators who want those.</summary>
    public async Task ProblemAsync(string title, string message)
    {
        foreach (var u in Cfg.NotifyUsers.Where(u => u.Problems && !string.IsNullOrEmpty(u.Topic)))
        {
            await SendAsync(u.Topic, title, message, "warning", 4).ConfigureAwait(false);
        }
    }

    /// <summary>
    /// Episodes of one season imported close together become one message: the first starts a
    /// short wait, the rest join it.
    /// </summary>
    public void EpisodesReady(IEnumerable<Guid> owners, string series, int season, IEnumerable<int> episodes)
    {
        var key = $"{series}|{season}";
        lock (_batches)
        {
            if (_batches.TryGetValue(key, out var batch))
            {
                batch.Episodes.UnionWith(episodes);
                batch.Owners.UnionWith(owners);
                return;
            }

            batch = new EpisodeBatchState(new HashSet<int>(episodes), new HashSet<Guid>(owners));
            _batches[key] = batch;
        }

        _ = Task.Run(async () =>
        {
            await Task.Delay(EpisodeBatch).ConfigureAwait(false);
            EpisodeBatchState done;
            lock (_batches)
            {
                done = _batches[key];
                _batches.Remove(key);
            }

            var (title, text) = EpisodeMessage(series, season, done.Episodes);
            await ReadyAsync(done.Owners, title, text).ConfigureAwait(false);
        });
    }

    internal static (string Title, string Message) EpisodeMessage(string series, int season, IEnumerable<int> episodes)
    {
        var list = episodes.OrderBy(e => e).ToList();
        if (list.Count == 1)
        {
            return ($"Ready: {series} S{season:00}E{list[0]:00}", $"{series} season {season} episode {list[0]} is ready to watch.");
        }

        return ($"Ready: {series} S{season:00} ({list.Count} episodes)",
            $"{series} season {season}: episodes {string.Join(", ", list)} are ready to watch.");
    }

    private sealed record EpisodeBatchState(HashSet<int> Episodes, HashSet<Guid> Owners);
}

/// <summary>Who started a download.</summary>
public sealed class GrabOwner
{
    public string DownloadId { get; set; } = string.Empty;

    public string UserId { get; set; } = string.Empty;

    public DateTimeOffset At { get; set; }
}
