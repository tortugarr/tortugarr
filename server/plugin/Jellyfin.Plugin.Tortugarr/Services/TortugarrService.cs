using System.Collections.Concurrent;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>What the app asks to search for (spec 3.2).</summary>
public sealed class SearchRequest
{
    public string Type { get; set; } = string.Empty;   // movie | episode | season

    public int? TmdbId { get; set; }

    public int? TvdbId { get; set; }

    public int? Season { get; set; }

    public int? Episode { get; set; }

    public string Query { get; set; } = string.Empty;   // adult searches

    /// <summary>Spec 3.2: keep releases below the quality minimum (SD), marked sd; every other filter still applies.</summary>
    public bool AllowSd { get; set; }

    public string Key => $"{Type}:{TmdbId}:{TvdbId}:{Season}:{Episode}:{Query}:{AllowSd}";
}

/// <summary>A running or finished search (spec 3.2), kept 30 minutes.</summary>
public sealed class SearchJob
{
    public string Id { get; } = Guid.NewGuid().ToString("N");

    public Guid UserId { get; init; }

    public SearchRequest Request { get; init; } = new();

    public DateTimeOffset Started { get; } = DateTimeOffset.UtcNow;

    public DateTimeOffset? Finished { get; set; }

    public string Status { get; set; } = "running";

    public object? Result { get; set; }

    public string? ErrorCode { get; set; }

    public string? ErrorMessage { get; set; }

    /// <summary>The releases the user was shown, by guid|indexerId - only these can be grabbed.</summary>
    public ConcurrentDictionary<string, ReleaseDto> Shown { get; } = new();

    /// <summary>Adult releases shown (spec 3.9), with their links - never sent to the app.</summary>
    public ConcurrentDictionary<string, ArrRelease> AdultShown { get; } = new();

    public int ArrId { get; set; }

    public bool IsMovie => Request.Type == "movie";
}

/// <summary>Everything the routes do, on the server. The app never sees a key.</summary>
public sealed class TortugarrService
{
    private static readonly TimeSpan Keep = TimeSpan.FromMinutes(30);
    private readonly IHttpClientFactory _httpFactory;
    private readonly ILogger<TortugarrService> _log;
    private readonly ConcurrentDictionary<string, SearchJob> _jobs = new();
    private readonly AdultLibraryService _adultLibrary;

    public TortugarrService(IHttpClientFactory httpFactory, ILogger<TortugarrService> log, AdultLibraryService adultLibrary)
    {
        _httpFactory = httpFactory;
        _log = log;
        _adultLibrary = adultLibrary;
    }

    private static PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new PluginConfiguration();

    private HttpClient Http
    {
        get
        {
            var c = _httpFactory.CreateClient("tortugarr");
            c.Timeout = Timeout.InfiniteTimeSpan; // every call has its own deadline
            return c;
        }
    }

    public ArrClient Radarr => new(Http, "Radarr", Cfg.RadarrUrl, Cfg.RadarrApiKey);

    public ArrClient Sonarr => new(Http, "Sonarr", Cfg.SonarrUrl, Cfg.SonarrApiKey);

    public ArrClient Prowlarr => new(Http, "Prowlarr", Cfg.ProwlarrUrl, Cfg.ProwlarrApiKey, "/api/v1");

    /// <summary>Seerr (API v1, X-Api-Key) - only to clear titles after deletes (spec 3.10, 3.11).</summary>
    public ArrClient Seerr => new(Http, "Seerr", Cfg.SeerrUrl, Cfg.SeerrApiKey, "/api/v1");

    internal QbitClient Qbit => Cfg.DownloadClientType == "qbittorrent"
        ? new QbitClient(Http, QbitUrl, Cfg.DownloadClientUsername, Cfg.DownloadClientPassword)
        : throw new NotConfiguredException("qBittorrent");

    private static readonly TimeSpan QbitAddressFresh = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan QbitAddressFirstWait = TimeSpan.FromSeconds(3);
    private static (string Url, DateTime At)? _arrQbit;
    private static DateTime _arrQbitTried = DateTime.MinValue;
    private static Task? _arrQbitRefresh;
    private static readonly object ArrQbitLock = new();

    /// <summary>
    /// qBittorrent's address: the one Radarr (else Sonarr) downloads to, so the plugin cannot
    /// drift from the *arrs when the download client is moved there; the configured
    /// DownloadClientUrl when neither answers. Re-read every few minutes in the background.
    /// </summary>
    internal string QbitUrl
    {
        get
        {
            var known = _arrQbit;
            Task? refresh = null;
            lock (ArrQbitLock)
            {
                var stale = DateTime.UtcNow - _arrQbitTried > QbitAddressFresh;
                if (stale && (_arrQbitRefresh is null || _arrQbitRefresh.IsCompleted))
                {
                    _arrQbitTried = DateTime.UtcNow;
                    _arrQbitRefresh = RefreshQbitUrlAsync();
                }

                refresh = _arrQbitRefresh;
            }

            if (known is null && refresh is not null)
            {
                // First use: give the *arr a moment rather than starting on a stale setting.
                refresh.Wait(QbitAddressFirstWait);
                known = _arrQbit;
            }

            return known?.Url ?? Cfg.DownloadClientUrl;
        }
    }

    private async Task RefreshQbitUrlAsync()
    {
        foreach (var (name, arr) in new (string, Func<ArrClient>)[] { ("Radarr", () => Radarr), ("Sonarr", () => Sonarr) })
        {
            try
            {
                var url = ArrQbitAddress.From(
                    await arr().Get("/downloadclient", CancellationToken.None, 10).ConfigureAwait(false));
                if (url is null)
                {
                    continue;
                }

                if (_arrQbit?.Url != url)
                {
                    _log.LogInformation("qBittorrent address from {Arr}: {Url} (plugin setting: {Configured})", name, url, Cfg.DownloadClientUrl);
                }

                _arrQbit = (url, DateTime.UtcNow);
                return;
            }
            catch (Exception e)
            {
                _log.LogDebug(e, "qBittorrent address from {Arr} not available", name);
            }
        }
    }

    /// <summary>The adult library is usable: switched on, Prowlarr set, qBittorrent as the client.</summary>
    public static bool AdultReady(Configuration.PluginConfiguration c) =>
        c.AdultEnabled && c.DownloadClientType == "qbittorrent" && !string.IsNullOrWhiteSpace(c.DownloadClientUrl)
        && !string.IsNullOrWhiteSpace(c.ProwlarrUrl) && !string.IsNullOrWhiteSpace(c.ProwlarrApiKey);

    // ------------------------------------------------------------------ capabilities

    public async Task<object> CapabilitiesAsync(bool isAdmin)
    {
        if (AdultReady(Cfg))
        {
            await _adultLibrary.EnsureAsync().ConfigureAwait(false); // creates and hides the library once
        }

        return Capabilities(isAdmin);
    }

    public object Capabilities(bool isAdmin)
    {
        var c = Cfg;
        bool Has(string url, string key) => !string.IsNullOrWhiteSpace(url) && !string.IsNullOrWhiteSpace(key);
        var arrs = Has(c.SonarrUrl, c.SonarrApiKey) && Has(c.RadarrUrl, c.RadarrApiKey);
        var qbit = c.DownloadClientType == "qbittorrent" && !string.IsNullOrWhiteSpace(c.DownloadClientUrl);
        return new
        {
            apiVersion = 1,
            pluginVersion = typeof(Plugin).Assembly.GetName().Version?.ToString() ?? "0",
            isAdmin,
            features = new
            {
                downloadNow = isAdmin && arrs,
                downloads = isAdmin && arrs,
                diskSpace = isAdmin && (qbit || arrs),
                videoCheck = isAdmin && arrs && qbit,
                subtitles = isAdmin && arrs && Has(c.BazarrUrl, c.BazarrApiKey),
                deleteTitles = isAdmin && (Has(c.SonarrUrl, c.SonarrApiKey) || Has(c.RadarrUrl, c.RadarrApiKey)),
                missingEpisodes = isAdmin && Has(c.SonarrUrl, c.SonarrApiKey),
                freeSpace = isAdmin && qbit && (Has(c.SonarrUrl, c.SonarrApiKey) || Has(c.RadarrUrl, c.RadarrApiKey)),
                adult = isAdmin && AdultReady(c),
            },
            categories = new { movies = c.MovieCategory, tv = c.TvCategory },
        };
    }

    // ------------------------------------------------------------------ search jobs

    public SearchJob StartSearch(Guid userId, SearchRequest req)
    {
        Validate(req);
        Cleanup();
        var running = _jobs.Values.FirstOrDefault(j => j.UserId == userId && j.Request.Key == req.Key && j.Status == "running");
        if (running is not null)
        {
            return running; // the same search again: the job that is already running
        }

        var job = new SearchJob { UserId = userId, Request = req };
        _jobs[job.Id] = job;
        _ = Task.Run(() => RunSearch(job));
        return job;
    }

    public SearchJob? GetJob(Guid userId, string id)
    {
        Cleanup();
        return _jobs.TryGetValue(id, out var j) && j.UserId == userId ? j : null;
    }

    private static void Validate(SearchRequest r)
    {
        var ok = r.Type switch
        {
            "movie" => r.TmdbId > 0,
            "episode" => r.TvdbId > 0 && r.Season >= 0 && r.Episode > 0,
            "season" => r.TvdbId > 0 && r.Season >= 0,
            _ => false,   // adult searches have their own route
        };
        if (!ok)
        {
            throw new ArgumentException("type must be movie (tmdbId), episode (tvdbId, season, episode) or season (tvdbId, season)");
        }
    }

    private void Cleanup()
    {
        foreach (var (id, j) in _jobs)
        {
            if (j.Finished is not null && DateTimeOffset.UtcNow - j.Finished > Keep)
            {
                _jobs.TryRemove(id, out _);
            }
        }
    }

    private async Task RunSearch(SearchJob job)
    {
        var timeout = Math.Max(30, Cfg.SearchTimeoutSeconds);
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeout));
        try
        {
            job.Result = job.IsMovie ? await SearchMovie(job, timeout, cts.Token).ConfigureAwait(false)
                                     : await SearchTv(job, timeout, cts.Token).ConfigureAwait(false);
            job.Status = "done";
        }
        catch (OperationCanceledException)
        {
            job.Status = "failed";
            job.ErrorCode = "timeout";
            job.ErrorMessage = $"the search took longer than {timeout} s";
        }
        catch (NotConfiguredException e)
        {
            job.Status = "failed";
            job.ErrorCode = "not_configured";
            job.ErrorMessage = e.Message;
        }
        catch (NoIndexersException e)
        {
            job.Status = "failed";
            job.ErrorCode = "no_indexers";
            job.ErrorMessage = e.Message;
        }
        catch (UpstreamException e)
        {
            job.Status = "failed";
            job.ErrorCode = e.Message.Contains("no answer within", StringComparison.Ordinal) ? "timeout" : "upstream_failed";
            job.ErrorMessage = e.Message;
        }
        catch (Exception e)
        {
            _log.LogError(e, "Tortugarr search failed");
            job.Status = "failed";
            job.ErrorCode = "upstream_failed";
            job.ErrorMessage = e.Message;
        }
        finally
        {
            job.Finished = DateTimeOffset.UtcNow;
            if (job.Status != "done")
            {
                _log.LogInformation("Tortugarr search {Type} ended {Status} ({Code}: {Message}) after {Seconds:0} s",
                    job.Request.Type, job.Status, job.ErrorCode, job.ErrorMessage, (job.Finished.Value - job.Started).TotalSeconds);
            }
        }
    }

    private async Task<object> SearchMovie(SearchJob job, int timeout, CancellationToken ct)
    {
        var radarr = Radarr;
        var movie = await EnsureMovie(radarr, job.Request.TmdbId!.Value, ct).ConfigureAwait(false);
        job.ArrId = (int)movie["id"]!;
        var home = HomeRelease(movie);
        var raw = await radarr.Get($"/release?movieId={job.ArrId}", ct, timeout).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        if (raw.Count == 0)
        {
            await RequireActiveIndexers(radarr, false, ct).ConfigureAwait(false);
            if (!string.IsNullOrWhiteSpace(Cfg.ProwlarrUrl) && !string.IsNullOrWhiteSpace(Cfg.ProwlarrApiKey))
            {
                // Its indexers come from Prowlarr, which may have disabled them before the *arr notices.
                await RequireActiveIndexers(Prowlarr, true, ct).ConfigureAwait(false);
            }
        }

        var filter = new ReleaseFilter(Cfg);
        var (releases, early) = filter.Apply(raw.Where(x => x is not null).Select(x => ArrRelease.FromJson(x!)), "movie", home, job.Request.AllowSd);
        LogSearch(job, "Radarr", raw.Count, releases.Count, filter, early);
        Remember(job, releases);
        var unavailable = await UnavailableIndexers(radarr, ct).ConfigureAwait(false);
        return new { title = (string?)movie["title"], year = (int?)movie["year"], arrId = job.ArrId, droppedEarly = early, dropped = filter.Dropped, unavailableIndexers = unavailable, releases };
    }

    private async Task<object> SearchTv(SearchJob job, int timeout, CancellationToken ct)
    {
        var sonarr = Sonarr;
        var r = job.Request;
        var series = await EnsureSeries(sonarr, r.TvdbId!.Value, ct).ConfigureAwait(false);
        var seriesId = (int)series["id"]!;
        string path;
        if (r.Type == "episode")
        {
            var ep = await FindEpisode(sonarr, seriesId, r.Season!.Value, r.Episode!.Value, ct).ConfigureAwait(false);
            job.ArrId = (int)ep["id"]!;
            path = $"/release?episodeId={job.ArrId}";
        }
        else
        {
            job.ArrId = seriesId;
            path = $"/release?seriesId={seriesId}&seasonNumber={r.Season}";
        }

        var raw = await sonarr.Get(path, ct, timeout).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        if (raw.Count == 0)
        {
            await RequireActiveIndexers(sonarr, false, ct).ConfigureAwait(false);
            if (!string.IsNullOrWhiteSpace(Cfg.ProwlarrUrl) && !string.IsNullOrWhiteSpace(Cfg.ProwlarrApiKey))
            {
                // Its indexers come from Prowlarr, which may have disabled them before the *arr notices.
                await RequireActiveIndexers(Prowlarr, true, ct).ConfigureAwait(false);
            }
        }

        var filter = new ReleaseFilter(Cfg);
        var (releases, early) = filter.Apply(raw.Where(x => x is not null).Select(x => ArrRelease.FromJson(x!)), r.Type, null, r.AllowSd);
        LogSearch(job, "Sonarr", raw.Count, releases.Count, filter, early);
        Remember(job, releases);
        var unavailable = await UnavailableIndexers(sonarr, ct).ConfigureAwait(false);
        return new { title = (string?)series["title"], year = (int?)series["year"], arrId = job.ArrId, droppedEarly = early, dropped = filter.Dropped, unavailableIndexers = unavailable, releases };
    }

    /// <summary>
    /// After an empty search: throws when the service has no indexer it can search with, so the app
    /// can say so instead of "nothing found" (spec 3.2). Radarr/Sonarr: interactive search on;
    /// Prowlarr: enabled; both: not disabled after failures.
    /// </summary>
    private static async Task RequireActiveIndexers(ArrClient arr, bool prowlarr, CancellationToken ct)
    {
        var indexers = await arr.Get("/indexer", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        JsonArray status;
        string? failing = null;
        try
        {
            status = await arr.Get("/indexerstatus", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        }
        catch (UpstreamException e) when (e.Message.Contains("HTTP 404", StringComparison.Ordinal))
        {
            // Radarr 6 / Sonarr 4 have no /indexerstatus; their health check says when every
            // indexer is unavailable after failures.
            status = new JsonArray();
            var health = await arr.Get("/health", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
            static bool AllFailing(JsonNode h)
            {
                var source = (string?)h["source"] ?? string.Empty;
                return (string?)h["type"] == "error"
                    && (source.StartsWith("IndexerStatus", StringComparison.Ordinal) || source.StartsWith("IndexerLongTermStatus", StringComparison.Ordinal));
            }

            failing = health.Where(h => h is not null && AllFailing(h!))
                .Select(h => (string?)h!["message"]).FirstOrDefault(m => !string.IsNullOrWhiteSpace(m));
        }

        var why = NoActiveIndexers(arr.Name, indexers, status, prowlarr, DateTimeOffset.UtcNow, failing);
        if (why is not null)
        {
            throw new NoIndexersException(why);
        }
    }

    /// <summary>Null when at least one indexer can search, else the reason for the app.</summary>
    internal static string? NoActiveIndexers(string service, JsonArray indexers, JsonArray status, bool prowlarr, DateTimeOffset now, string? healthFailing = null)
    {
        var disabledTill = status.Where(x => x is not null)
            .Select(x => (Id: (int?)x!["indexerId"] ?? 0, Till: DateTimeOffset.TryParse((string?)x["disabledTill"], out var t) ? t : (DateTimeOffset?)null))
            .Where(x => x.Till > now).ToDictionary(x => x.Id, x => x.Till!.Value);
        var on = indexers.Where(x => x is not null && ((bool?)x[prowlarr ? "enable" : "enableInteractiveSearch"] ?? false)).Select(x => (int?)x!["id"] ?? 0).ToList();
        if (on.Count > 0 && healthFailing is not null)
        {
            return $"{service} has no active indexers: {healthFailing}";
        }

        if (on.Any(id => !disabledTill.ContainsKey(id)))
        {
            return null;
        }

        if (indexers.Count == 0)
        {
            return $"{service} has no indexers";
        }

        if (on.Count == 0)
        {
            return $"{service} has no active indexers: every indexer is switched off for searches";
        }

        var until = on.Select(id => disabledTill[id]).Min();
        return $"{service} has no active indexers: {on.Count} disabled until {until:HH:mm} UTC after failures";
    }

    /// <summary>
    /// Spec 3.2: indexers that are switched off after failures - from Radarr's/Sonarr's health
    /// check and from Prowlarr's own block list (Prowlarr can disable one before the *arr notices).
    /// Best effort: a failed lookup gives an empty list, never a failed search.
    /// </summary>
    private async Task<List<string>> UnavailableIndexers(ArrClient? arr, CancellationToken ct)
    {
        var names = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        try
        {
            if (arr is not null)
            {
                foreach (var h in await arr.Get("/health", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
                {
                    var source = (string?)h?["source"] ?? string.Empty;
                    if (source.StartsWith("IndexerStatus", StringComparison.Ordinal) || source.StartsWith("IndexerLongTermStatus", StringComparison.Ordinal))
                    {
                        names.UnionWith(NamesFromHealth((string?)h!["message"]));
                    }
                }
            }

            var c = Cfg;
            if (!string.IsNullOrWhiteSpace(c.ProwlarrUrl) && !string.IsNullOrWhiteSpace(c.ProwlarrApiKey))
            {
                var now = DateTimeOffset.UtcNow;
                var blocked = (await Prowlarr.Get("/indexerstatus", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
                    .Where(s => DateTimeOffset.TryParse((string?)s?["disabledTill"], out var t) && t > now)
                    .Select(s => (int?)s!["indexerId"] ?? 0).ToHashSet();
                if (blocked.Count > 0)
                {
                    foreach (var i in await Prowlarr.Get("/indexer", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
                    {
                        if (blocked.Contains((int?)i?["id"] ?? 0) && (string?)i!["name"] is { Length: > 0 } n)
                        {
                            names.Add(n);
                        }
                    }
                }
            }
        }
        catch (Exception e) when (e is UpstreamException or NotConfiguredException)
        {
            _log.LogDebug("Tortugarr: could not read which indexers are unavailable: {Message}", e.Message);
        }

        return names.ToList();
    }

    /// <summary>"Indexers unavailable due to failures[ for more than 6 hours]: A (Prowlarr), B (Prowlarr)" -> A, B.</summary>
    internal static IEnumerable<string> NamesFromHealth(string? message)
    {
        var colon = message?.IndexOf(':') ?? -1;
        if (message is null || colon < 0)
        {
            return Array.Empty<string>();
        }

        return message[(colon + 1)..].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(n => n.EndsWith(" (Prowlarr)", StringComparison.Ordinal) ? n[..^" (Prowlarr)".Length] : n)
            .Where(n => n.Length > 0);
    }

    /// <summary>One line per search: what the *arr returned, what the filters kept and dropped, and the time.</summary>
    private void LogSearch(SearchJob job, string arr, int raw, int kept, ReleaseFilter filter, int early)
    {
        var r = job.Request;
        var what = r.Type == "movie" ? $"movie tmdb={r.TmdbId}" : $"{r.Type} tvdb={r.TvdbId} S{r.Season:00}" + (r.Type == "episode" ? $"E{r.Episode:00}" : string.Empty);
        _log.LogInformation("Tortugarr search {What}: {Arr} {Raw} release(s), kept {Kept}, dropped: {Dropped}; droppedEarly {Early}; {Seconds:0} s",
            what, arr, raw, kept, filter.DroppedText(), early, (DateTimeOffset.UtcNow - job.Started).TotalSeconds);
    }

    private static void Remember(SearchJob job, List<ReleaseDto> releases)
    {
        foreach (var x in releases)
        {
            job.Shown[$"{x.Guid}|{x.IndexerId}"] = x;
        }
    }

    // ------------------------------------------------------------------ adult library (spec 3.9)

    private void RequireAdult()
    {
        if (!AdultReady(Cfg))
        {
            throw new FeatureOffException("the adult library is switched off on this server");
        }
    }

    public async Task<SearchJob> StartAdultSearch(Guid userId, string query)
    {
        RequireAdult();
        if (string.IsNullOrWhiteSpace(query))
        {
            throw new ArgumentException("query is empty");
        }

        await _adultLibrary.EnsureAsync().ConfigureAwait(false);
        Cleanup();
        var req = new SearchRequest { Type = "adult", Query = query.Trim() };
        var running = _jobs.Values.FirstOrDefault(j => j.UserId == userId && j.Request.Key == req.Key && j.Status == "running");
        if (running is not null)
        {
            return running;
        }

        var job = new SearchJob { UserId = userId, Request = req };
        _jobs[job.Id] = job;
        _ = Task.Run(() => RunAdultSearch(job));
        return job;
    }

    private async Task RunAdultSearch(SearchJob job)
    {
        var timeout = Math.Max(30, Cfg.SearchTimeoutSeconds);
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeout));
        try
        {
            var prowlarr = Prowlarr;
            var cats = string.Concat(Cfg.AdultCategories.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(c => "&categories=" + c.Trim()));
            var all = new List<ArrRelease>();
            foreach (var q in ReleaseFilter.AdultQueries(job.Request.Query))
            {
                var res = await prowlarr.Get($"/search?query={Uri.EscapeDataString(q)}&type=search&limit=100{cats}", cts.Token, timeout).ConfigureAwait(false);
                all.AddRange((res as JsonArray ?? new JsonArray()).Where(x => x is not null).Select(x => ArrRelease.FromJson(x!)));
            }

            if (all.Count == 0)
            {
                await RequireActiveIndexers(prowlarr, true, cts.Token).ConfigureAwait(false);
            }

            var ranked = new ReleaseFilter(Cfg).AdultMerge(job.Request.Query, all);
            _log.LogInformation("Tortugarr adult search: Prowlarr {Raw} release(s), kept {Kept}; {Seconds:0} s",
                all.Count, ranked.Count, (DateTimeOffset.UtcNow - job.Started).TotalSeconds);
            var releases = ranked.Select(x => new
            {
                guid = x.Release.Guid, indexerId = x.Release.IndexerId, indexer = x.Release.Indexer, title = x.Release.Title,
                size = x.Release.Size, seeders = x.Release.Seeders, leechers = x.Release.Leechers,
                publishDate = x.Release.PublishDate, matchedWords = x.MatchedWords,
            }).ToList();
            foreach (var x in ranked)
            {
                job.AdultShown[$"{x.Release.Guid}|{x.Release.IndexerId}"] = x.Release;
            }

            job.Result = new { query = job.Request.Query, unavailableIndexers = await UnavailableIndexers(null, cts.Token).ConfigureAwait(false), releases };
            job.Status = "done";
        }
        catch (OperationCanceledException)
        {
            job.Status = "failed";
            job.ErrorCode = "timeout";
            job.ErrorMessage = $"the search took longer than {timeout} s";
        }
        catch (Exception e) when (e is UpstreamException or NotConfiguredException or NoIndexersException)
        {
            job.Status = "failed";
            job.ErrorCode = e switch { NotConfiguredException => "not_configured", NoIndexersException => "no_indexers", _ => "upstream_failed" };
            job.ErrorMessage = e.Message;
        }
        catch (Exception e)
        {
            _log.LogError(e, "Tortugarr adult search failed");
            job.Status = "failed";
            job.ErrorCode = "upstream_failed";
            job.ErrorMessage = e.Message;
        }
        finally
        {
            job.Finished = DateTimeOffset.UtcNow;
        }
    }

    public sealed class AdultGrabRequest
    {
        public string SearchId { get; set; } = string.Empty;

        public string Guid { get; set; } = string.Empty;

        public int IndexerId { get; set; }
    }

    /// <summary>Only a release shown in that search; straight to qBittorrent (no *arr).</summary>
    public async Task<object> AdultGrab(Guid userId, AdultGrabRequest g, CancellationToken ct)
    {
        RequireAdult();
        var job = GetJob(userId, g.SearchId);
        if (job is null || job.Request.Type != "adult" || !job.AdultShown.TryGetValue($"{g.Guid}|{g.IndexerId}", out var rel))
        {
            throw new SearchExpiredException();
        }

        var url = !string.IsNullOrWhiteSpace(rel.MagnetUrl) ? rel.MagnetUrl : rel.DownloadUrl;
        var qbit = Qbit;
        var before = (await qbit.List(Cfg.AdultCategory, ct).ConfigureAwait(false)).Select(t => (string?)t?["hash"]).ToHashSet();
        await qbit.Add(url, Cfg.AdultCategory, Cfg.AdultSavePath, ct).ConfigureAwait(false);
        string? hash = null;
        for (var i = 0; i < 15 && hash is null; i++)
        {
            await Task.Delay(1000, ct).ConfigureAwait(false);
            hash = (await qbit.List(Cfg.AdultCategory, ct).ConfigureAwait(false)).Select(t => (string?)t?["hash"]).FirstOrDefault(h => h is not null && !before.Contains(h));
        }

        if (hash is not null)
        {
            _ = Task.Run(() => ScanWhenDone(hash), CancellationToken.None);
        }

        return new { downloadId = hash?.ToUpperInvariant(), title = rel.Title };
    }

    /// <summary>
    /// Waits for the adult download to finish, then scans the adult library. Polls only this one
    /// torrent, and gives up after a day; a restart is covered by the start-up scan.
    /// </summary>
    private async Task ScanWhenDone(string hash)
    {
        var until = DateTime.UtcNow.AddDays(1);
        while (DateTime.UtcNow < until)
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(20)).ConfigureAwait(false);
                var t = (await Qbit.List(Cfg.AdultCategory, CancellationToken.None).ConfigureAwait(false))
                    .FirstOrDefault(x => string.Equals((string?)x?["hash"], hash, StringComparison.OrdinalIgnoreCase));
                if (t is null)
                {
                    return; // removed before it finished
                }

                if (((double?)t["progress"] ?? 0) >= 1)
                {
                    await _adultLibrary.RescanAsync().ConfigureAwait(false);
                    return;
                }
            }
            catch (Exception e)
            {
                _log.LogWarning(e, "Tortugarr: waiting for an adult download failed; retrying");
            }
        }
    }

    private async Task<List<object>> AdultDownloads(CancellationToken ct)
    {
        var items = new List<object>();
        if (!AdultReady(Cfg))
        {
            return items;
        }

        foreach (var t in await Qbit.List(Cfg.AdultCategory, ct).ConfigureAwait(false))
        {
            if (t is null)
            {
                continue;
            }

            var state = ((string?)t["state"] ?? string.Empty).ToLowerInvariant();
            var progress = (double?)t["progress"] ?? 0;
            items.Add(new
            {
                downloadId = ((string?)t["hash"])?.ToUpperInvariant(),
                kind = "adult",
                title = (string?)t["name"],
                tmdbId = (int?)null, tvdbId = (int?)null, season = (int?)null, episode = (int?)null,
                status = state.Contains("error", StringComparison.Ordinal) || state == "missingfiles" ? "failed"
                    : state.StartsWith("paused", StringComparison.Ordinal) || state.StartsWith("stopped", StringComparison.Ordinal) ? (progress >= 1 ? "completed" : "paused")
                    : progress >= 1 ? "completed"
                    : state.Contains("queued", StringComparison.Ordinal) ? "queued" : "downloading",
                progress = Math.Round(progress, 3),
                sizeLeft = (long?)t["amount_left"] ?? 0,
                etaSeconds = (long?)t["eta"] is long eta && eta < 8640000 ? eta : (long?)null,
                messages = new List<string>(),
            });
        }

        return items;
    }

    private async Task<bool> IsAdultDownload(string hash, CancellationToken ct) =>
        AdultReady(Cfg) && (await Qbit.List(Cfg.AdultCategory, ct).ConfigureAwait(false))
            .Any(t => string.Equals((string?)t?["hash"], hash, StringComparison.OrdinalIgnoreCase));

    // ------------------------------------------------------------------ adding titles (spec 3.2)

    /// <summary>A movie missing in Radarr is added monitored, without a search - as the app does.</summary>
    private async Task<JsonNode> EnsureMovie(ArrClient radarr, int tmdbId, CancellationToken ct)
    {
        if (await radarr.Get($"/movie?tmdbId={tmdbId}", ct).ConfigureAwait(false) is JsonArray { Count: > 0 } have)
        {
            return have[0]!;
        }

        var found = await radarr.Get($"/movie/lookup/tmdb?tmdbId={tmdbId}", ct).ConfigureAwait(false)
                    ?? throw new UpstreamException("Radarr", $"no movie with TMDB id {tmdbId}");
        var body = found.DeepClone().AsObject();
        body["qualityProfileId"] = await DefaultProfile(radarr, ct).ConfigureAwait(false);
        body["rootFolderPath"] = await RootWithMostSpace(radarr, ct).ConfigureAwait(false);
        body["monitored"] = true;
        body["minimumAvailability"] = "released";
        body["addOptions"] = new JsonObject { ["searchForMovie"] = false, ["monitor"] = "movieOnly" };
        return await radarr.Post("/movie", body, ct).ConfigureAwait(false) ?? throw new UpstreamException("Radarr", "adding the movie failed");
    }

    /// <summary>A series missing in Sonarr is added unmonitored, without a search - as the app does.</summary>
    internal async Task<JsonNode> EnsureSeries(ArrClient sonarr, int tvdbId, CancellationToken ct)
    {
        if (await sonarr.Get($"/series?tvdbId={tvdbId}", ct).ConfigureAwait(false) is JsonArray { Count: > 0 } have)
        {
            return have[0]!;
        }

        var found = (await sonarr.Get($"/series/lookup?term=tvdb:{tvdbId}", ct).ConfigureAwait(false) as JsonArray)?.FirstOrDefault()
                    ?? throw new UpstreamException("Sonarr", $"no series with TVDB id {tvdbId}");
        var body = found.DeepClone().AsObject();
        body["qualityProfileId"] = await DefaultProfile(sonarr, ct).ConfigureAwait(false);
        body["rootFolderPath"] = await RootWithMostSpace(sonarr, ct).ConfigureAwait(false);
        body["monitored"] = false;
        body["monitorNewItems"] = "none";
        body["seasonFolder"] = true;
        if (body["seasons"] is JsonArray seasons)
        {
            foreach (var s in seasons)
            {
                if (s is JsonObject so)
                {
                    so["monitored"] = false;
                }
            }
        }

        body["addOptions"] = new JsonObject { ["monitor"] = "none", ["searchForMissingEpisodes"] = false, ["searchForCutoffUnmetEpisodes"] = false };
        return await sonarr.Post("/series", body, ct).ConfigureAwait(false) ?? throw new UpstreamException("Sonarr", "adding the series failed");
    }

    private static async Task<JsonNode> FindEpisode(ArrClient sonarr, int seriesId, int season, int episode, CancellationToken ct)
    {
        // A series that was just added gets its episode list a moment later.
        for (var i = 0; i < 20; i++)
        {
            if (await sonarr.Get($"/episode?seriesId={seriesId}&seasonNumber={season}", ct).ConfigureAwait(false) is JsonArray eps)
            {
                var ep = eps.FirstOrDefault(e => (int?)e?["episodeNumber"] == episode);
                if (ep is not null)
                {
                    return ep;
                }
            }

            await Task.Delay(3000, ct).ConfigureAwait(false);
        }

        throw new UpstreamException("Sonarr", $"season {season} episode {episode} not found");
    }

    /// <summary>The installer's default profile is preselected in Sonarr/Radarr; otherwise the first.</summary>
    private static async Task<int> DefaultProfile(ArrClient arr, CancellationToken ct)
    {
        var profiles = await arr.Get("/qualityprofile", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        var pick = profiles.FirstOrDefault(p => (string?)p?["name"] == "HD-1080p") ?? profiles.FirstOrDefault();
        return (int?)pick?["id"] ?? throw new UpstreamException(arr.Name, "no quality profile");
    }

    /// <summary>Quality profile by the picked release's tier, as the app does: Ultra-HD/4K/2160p, HD-1080p, HD-720p.</summary>
    private static async Task<int?> ProfileForTier(ArrClient arr, string title, CancellationToken ct)
    {
        var pattern = title.Contains("2160", StringComparison.Ordinal) ? "Ultra-HD|4K|2160p"
            : title.Contains("1080", StringComparison.Ordinal) ? "HD-1080p"
            : title.Contains("720", StringComparison.Ordinal) ? "HD-720p" : null;
        if (pattern is null)
        {
            return null;
        }

        var profiles = await arr.Get("/qualityprofile", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        return (int?)profiles.FirstOrDefault(p => Regex.IsMatch((string?)p?["name"] ?? string.Empty, "^(" + pattern + ")$", RegexOptions.IgnoreCase))?["id"];
    }

    private static async Task<string> RootWithMostSpace(ArrClient arr, CancellationToken ct)
    {
        var roots = await arr.Get("/rootfolder", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        var best = roots.Where(r => (bool?)r?["accessible"] != false).OrderByDescending(r => (long?)r?["freeSpace"] ?? 0).FirstOrDefault();
        return (string?)best?["path"] ?? throw new UpstreamException(arr.Name, "no root folder");
    }

    private static DateTimeOffset? HomeRelease(JsonNode movie)
    {
        var dates = new[] { (string?)movie["digitalRelease"], (string?)movie["physicalRelease"] }
            .Select(s => DateTimeOffset.TryParse(s, out var d) ? d : (DateTimeOffset?)null)
            .Where(d => d is not null).ToList();
        return dates.Count == 0 ? null : dates.Min();
    }

    // ------------------------------------------------------------------ grab (spec 3.3)

    public sealed class GrabRequest
    {
        public string Type { get; set; } = string.Empty;

        public int ArrId { get; set; }

        public string Guid { get; set; } = string.Empty;

        public int IndexerId { get; set; }

        public bool Force { get; set; }
    }

    /// <summary>Grab a release the user was shown. Movies: answers once the movie is in Radarr's queue (up to 60 s).</summary>
    public async Task<object> Grab(Guid userId, GrabRequest g, CancellationToken ct)
    {
        Cleanup();
        var job = _jobs.Values
            .Where(j => j.UserId == userId && j.Status == "done" && j.ArrId == g.ArrId && j.Request.Type == g.Type)
            .OrderByDescending(j => j.Finished)
            .FirstOrDefault(j => j.Shown.ContainsKey($"{g.Guid}|{g.IndexerId}"));
        if (job is null || !job.Shown.TryGetValue($"{g.Guid}|{g.IndexerId}", out var shown))
        {
            throw new SearchExpiredException();
        }

        if (!shown.Recommended && !g.Force)
        {
            throw new ArgumentException("this release has soft rejections; send force: true to take it anyway");
        }

        var arr = job.IsMovie ? Radarr : Sonarr;
        if (job.IsMovie && await ProfileForTier(arr, shown.Title, ct).ConfigureAwait(false) is int profile)
        {
            var movie = await arr.Get($"/movie/{job.ArrId}", ct).ConfigureAwait(false);
            if (movie is JsonObject m && (int?)m["qualityProfileId"] != profile)
            {
                m["qualityProfileId"] = profile;
                await arr.Put($"/movie/{job.ArrId}", m, ct).ConfigureAwait(false);
            }
        }

        try
        {
            await arr.Post("/release", GrabBody(job.Request.Type, job.ArrId, g.Guid, g.IndexerId), ct, 60).ConfigureAwait(false);
        }
        catch (UpstreamException e) when (e.Message.Contains("in cache", StringComparison.OrdinalIgnoreCase))
        {
            // Only "not in the release cache" means the search is too old; any other 404 is reported
            // as it is (a grab of an SD release once came back as "search expired": Radarr had
            // answered "Unable to find matching movie").
            throw new SearchExpiredException();
        }
        catch (UpstreamException) when (Cfg.DownloadClientType == "qbittorrent")
        {
            // The *arr only says "Failed to connect to qBittorrent" when qBittorrent refused a
            // torrent it already has (HTTP 409). Say what is really going on; never delete it.
            JsonNode? hit = null;
            try
            {
                hit = FindTorrent(await Qbit.ListAll(ct).ConfigureAwait(false), shown.InfoHash, shown.Title);
            }
            catch (Exception e) when (e is UpstreamException or NotConfiguredException)
            {
                _log.LogWarning("Tortugarr: could not look in qBittorrent after a failed grab: {Message}", e.Message);
            }

            if (hit is not null)
            {
                throw new AlreadyInClientException(((string?)hit["hash"] ?? string.Empty).ToUpperInvariant(),
                    (string?)hit["category"] ?? string.Empty, Math.Round((double?)hit["progress"] ?? 0, 3), (string?)hit["state"] ?? string.Empty);
            }

            throw;
        }

        // The movie's Seerr request (made by the app) must wait until Radarr has it queued.
        var (queued, downloadId) = await WaitQueued(arr, job, TimeSpan.FromSeconds(job.IsMovie ? 60 : 30), ct).ConfigureAwait(false);
        return new { downloadId, title = shown.Title, queued };
    }

    /// <summary>
    /// The body of the *arr's POST /release. The search was made for this title, so its id goes along:
    /// Radarr/Sonarr use it only when they could not match the release themselves (often for SD or
    /// oddly named releases) and otherwise answer 404 "Unable to find matching movie/series".
    /// </summary>
    internal static Dictionary<string, object> GrabBody(string type, int arrId, string guid, int indexerId)
    {
        var body = new Dictionary<string, object> { ["guid"] = guid, ["indexerId"] = indexerId };
        var key = type switch { "movie" => "movieId", "episode" => "episodeId", _ => "seriesId" };
        body[key] = arrId;
        return body;
    }

    /// <summary>The torrent for a release: by info hash when known, else by name (file extension ignored).</summary>
    internal static JsonNode? FindTorrent(JsonArray torrents, string infoHash, string title)
    {
        static string Norm(string s) => Regex.Replace(s.ToLowerInvariant(), "[^a-z0-9]+", string.Empty);

        // A single-file torrent is named after its file; only a video extension is dropped.
        static string Name(string s) => Norm(Regex.Replace(s.Trim(), @"\.(mkv|mp4|m4v|avi|mov|ts|wmv|webm|mpg|mpeg)$", string.Empty, RegexOptions.IgnoreCase));

        var list = torrents.Where(t => t is not null).Select(t => t!).ToList();
        if (!string.IsNullOrWhiteSpace(infoHash))
        {
            var byHash = list.FirstOrDefault(t => string.Equals((string?)t["hash"], infoHash, StringComparison.OrdinalIgnoreCase));
            if (byHash is not null)
            {
                return byHash;
            }
        }

        var want = Norm(title);
        return want.Length == 0 ? null : list.FirstOrDefault(t => Name((string?)t["name"] ?? string.Empty) == want);
    }

    /// <summary>
    /// True once Radarr/Sonarr has the grab in its queue (or already imported it). The app makes
    /// the Seerr request only then: that request makes the *arr search, and its search only sees
    /// downloads in its queue. The queue is rebuilt from the download client about once a minute,
    /// so a "grabbed" history entry alone is too early - on 2026-10-20 a Seerr request seven
    /// seconds after the grab got a second copy of the same movie. Asking for
    /// RefreshMonitoredDownloads puts the grab in the queue within seconds.
    /// </summary>
    private static async Task<(bool, string?)> WaitQueued(ArrClient arr, SearchJob job, TimeSpan wait, CancellationToken ct)
    {
        var since = DateTimeOffset.UtcNow.AddSeconds(-5);
        var end = DateTimeOffset.UtcNow + wait;
        string? downloadId = null;
        var refreshed = DateTimeOffset.MinValue;
        while (DateTimeOffset.UtcNow < end)
        {
            // No eventType in the query: Sonarr 4 only takes it as a number there (HTTP 400 for
            // "grabbed"), while every answer names it as text - so it is filtered here.
            var hist = await arr.Get(job.IsMovie ? $"/history/movie?movieId={job.ArrId}"
                : job.Request.Type == "episode" ? $"/history?episodeId={job.ArrId}&pageSize=50&sortKey=date&sortDirection=descending"
                : $"/history/series?seriesId={job.ArrId}", ct).ConfigureAwait(false);
            var recent = (hist as JsonArray ?? hist?["records"] as JsonArray ?? new JsonArray())
                .Where(h => DateTimeOffset.TryParse((string?)h?["date"], out var d) && d >= since)
                .ToList();
            downloadId ??= recent
                .Where(h => string.Equals((string?)h?["eventType"], "grabbed", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(h => (string?)h?["date"])
                .Select(h => (string?)h?["downloadId"])
                .FirstOrDefault();

            // A fast download can be imported - and gone from the queue - before we look.
            if (downloadId is not null && recent.Any(h =>
                    string.Equals((string?)h?["downloadId"], downloadId, StringComparison.OrdinalIgnoreCase)
                    && ((string?)h?["eventType"] ?? string.Empty).Contains("Imported", StringComparison.OrdinalIgnoreCase)))
            {
                return (true, downloadId);
            }

            var q = await arr.Get("/queue?pageSize=200", ct).ConfigureAwait(false);
            if (q?["records"] is JsonArray recs)
            {
                var hit = recs.FirstOrDefault(r => job.IsMovie
                    ? (int?)r?["movieId"] == job.ArrId
                    : job.Request.Type == "episode" ? (int?)r?["episodeId"] == job.ArrId : (int?)r?["seriesId"] == job.ArrId);
                if (hit is not null)
                {
                    return (true, (string?)hit["downloadId"]);
                }
            }

            // Grabbed but not in the queue yet: have the *arr read the download client now
            // instead of at its next minute.
            if (downloadId is not null && DateTimeOffset.UtcNow - refreshed > TimeSpan.FromSeconds(10))
            {
                refreshed = DateTimeOffset.UtcNow;
                try
                {
                    await arr.Post("/command", new JsonObject { ["name"] = "RefreshMonitoredDownloads" }, ct).ConfigureAwait(false);
                }
                catch (UpstreamException)
                {
                    // The minute refresh still comes.
                }
            }

            await Task.Delay(2000, ct).ConfigureAwait(false);
        }

        // Not in the queue in time: report it as not queued, so the app leaves Seerr alone
        // rather than risk a second download.
        return (false, downloadId);
    }

    // ------------------------------------------------------------------ downloads (3.4 - 3.6)

    public async Task<object> Downloads(CancellationToken ct)
    {
        var items = new List<object>();
        foreach (var (arr, kind) in new[] { (Radarr, "movie"), (Sonarr, "episode") })
        {
            var q = await arr.Get(kind == "movie" ? "/queue?pageSize=200&includeMovie=true" : "/queue?pageSize=200&includeSeries=true&includeEpisode=true", ct).ConfigureAwait(false);
            foreach (var r in q?["records"] as JsonArray ?? new JsonArray())
            {
                if (r is null)
                {
                    continue;
                }

                var size = (double?)r["size"] ?? 0;
                var left = (double?)r["sizeleft"] ?? 0;
                items.Add(new
                {
                    downloadId = (string?)r["downloadId"],
                    kind,
                    title = (string?)r["title"],
                    tmdbId = kind == "movie" ? (int?)r["movie"]?["tmdbId"] : null,
                    tvdbId = kind == "episode" ? (int?)r["series"]?["tvdbId"] : null,
                    season = kind == "episode" ? (int?)r["episode"]?["seasonNumber"] : null,
                    episode = kind == "episode" ? (int?)r["episode"]?["episodeNumber"] : null,
                    status = Status(r),
                    progress = size > 0 ? Math.Round((size - left) / size, 3) : 0,
                    sizeLeft = (long)left,
                    etaSeconds = TimeSpan.TryParse((string?)r["timeleft"], out var t) ? (long)t.TotalSeconds : (long?)null,
                    messages = (r["statusMessages"] as JsonArray ?? new JsonArray())
                        .SelectMany(m => (m?["messages"] as JsonArray ?? new JsonArray()).Select(x => (string?)x))
                        .Where(x => !string.IsNullOrEmpty(x)).ToList(),
                });
            }
        }

        items.AddRange(await AdultDownloads(ct).ConfigureAwait(false));
        return new { items };
    }

    private static string Status(JsonNode r)
    {
        var tracked = ((string?)r["trackedDownloadState"] ?? string.Empty).ToLowerInvariant();
        var status = ((string?)r["status"] ?? string.Empty).ToLowerInvariant();
        return tracked switch
        {
            "importpending" => "importPending",
            "importing" => "importing",
            "imported" => "completed",
            "failedpending" or "failed" => "failed",
            _ => status switch
            {
                "queued" or "delay" => "queued",
                "paused" => "paused",
                "completed" => "completed",
                "failed" => "failed",
                "warning" => "warning",
                _ => "downloading",
            },
        };
    }

    /// <summary>The *arr and queue record that hold a download id.</summary>
    private async Task<(ArrClient Arr, JsonNode Record)> FindQueued(string downloadId, CancellationToken ct)
    {
        foreach (var arr in new[] { Radarr, Sonarr })
        {
            var q = await arr.Get("/queue?pageSize=200", ct).ConfigureAwait(false);
            var hit = (q?["records"] as JsonArray)?.FirstOrDefault(r => string.Equals((string?)r?["downloadId"], downloadId, StringComparison.OrdinalIgnoreCase));
            if (hit is not null)
            {
                return (arr, hit);
            }
        }

        throw new KeyNotFoundException("download not found");
    }

    public async Task Remove(string downloadId, bool blocklist, CancellationToken ct)
    {
        if (await IsAdultDownload(downloadId, ct).ConfigureAwait(false))
        {
            await Qbit.Delete(downloadId, deleteFiles: true, ct).ConfigureAwait(false); // no *arr, so no blocklist
            return;
        }

        var (arr, rec) = await FindQueued(downloadId, ct).ConfigureAwait(false);
        await arr.Delete($"/queue/{(int)rec["id"]!}?removeFromClient=true&blocklist={(blocklist ? "true" : "false")}&skipRedownload=false", ct).ConfigureAwait(false);
    }

    public async Task<object> Check(string downloadId, CancellationToken ct)
    {
        var c = Cfg;
        if (c.DownloadClientType != "qbittorrent")
        {
            throw new NotConfiguredException("the video check (needs qBittorrent)");
        }

        // qBittorrent itself, not the Radarr/Sonarr queue: a grab is not in the queue at once, and a
        // fast download is imported and gone from it before the app asks (lab: 404 for 79 s).
        var qbit = new QbitClient(Http, QbitUrl, c.DownloadClientUsername, c.DownloadClientPassword);
        var torrent = (await qbit.ListAll(ct).ConfigureAwait(false))
            .FirstOrDefault(t => string.Equals((string?)t?["hash"], downloadId, StringComparison.OrdinalIgnoreCase));
        var category = (string?)torrent?["category"];
        if (torrent is null || (category != c.MovieCategory && category != c.TvCategory && category != c.AdultCategory))
        {
            throw new KeyNotFoundException("download not found in qBittorrent");
        }

        var files = await qbit.Files(downloadId, ct).ConfigureAwait(false);
        if (files is null)
        {
            return new { hasVideo = (bool?)null, files = Array.Empty<object>(), action = "wait" };
        }

        var filter = new ReleaseFilter(c);
        var hasVideo = files.Any(f => filter.IsVideo(f.Name, f.Size));
        if (!hasVideo)
        {
            await RemoveWithoutVideo(downloadId, category!, ct).ConfigureAwait(false);
        }

        return new { hasVideo, files = files.Select(f => new { name = f.Name, size = f.Size }), action = hasVideo ? "kept" : "removed" };
    }

    /// <summary>
    /// A download without a video: removed and its release blocklisted - through the queue when
    /// Radarr/Sonarr list it, otherwise by marking its grab failed in their history (which
    /// blocklists it too) and removing the torrent with its files.
    /// </summary>
    private async Task RemoveWithoutVideo(string downloadId, string category, CancellationToken ct)
    {
        var c = Cfg;
        if (category == c.AdultCategory)
        {
            await Qbit.Delete(downloadId, deleteFiles: true, ct).ConfigureAwait(false);
            return;
        }

        try
        {
            await Remove(downloadId, blocklist: true, ct).ConfigureAwait(false);
            return;
        }
        catch (KeyNotFoundException)
        {
            // not in the queue (yet or any more)
        }

        var arr = category == c.MovieCategory ? Radarr : Sonarr;
        var hist = await arr.Get($"/history?downloadId={Uri.EscapeDataString(downloadId)}&pageSize=50", ct).ConfigureAwait(false);
        var grabbed = (hist?["records"] as JsonArray ?? new JsonArray())
            .FirstOrDefault(h => string.Equals((string?)h?["eventType"], "grabbed", StringComparison.OrdinalIgnoreCase));
        if (grabbed is not null)
        {
            await arr.Post($"/history/failed/{(int)grabbed["id"]!}", new JsonObject(), ct).ConfigureAwait(false);
        }

        await Qbit.Delete(downloadId, deleteFiles: true, ct).ConfigureAwait(false);
    }

    public async Task<object> Space(CancellationToken ct)
    {
        var c = Cfg;
        if (c.DownloadClientType == "qbittorrent")
        {
            var qbit = new QbitClient(Http, QbitUrl, c.DownloadClientUsername, c.DownloadClientPassword);
            var free = await qbit.FreeSpace(ct).ConfigureAwait(false);
            if (free is not null)
            {
                return new { path = "/data/torrents", freeBytes = free.Value, totalBytes = (long?)null };
            }
        }

        // Other clients: Radarr's view of the disk that holds /data.
        var disks = await Radarr.Get("/diskspace", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        var d = disks.Where(x => "/data".StartsWith(((string?)x?["path"] ?? "\u0000").TrimEnd('/') + "/", StringComparison.Ordinal) || (string?)x?["path"] == "/data")
            .OrderByDescending(x => ((string?)x?["path"])?.Length ?? 0).FirstOrDefault() ?? disks.FirstOrDefault();
        return new { path = (string?)d?["path"] ?? "/data", freeBytes = (long?)d?["freeSpace"] ?? 0, totalBytes = (long?)d?["totalSpace"] };
    }

    // ------------------------------------------------------------------ subtitles (3.8)

    private BazarrClient Bazarr => new(Http, Cfg.BazarrUrl, Cfg.BazarrApiKey);

    /// <summary>Bazarr knows movies by Radarr id and episodes by Sonarr episode id.</summary>
    private async Task<(string Kind, int MovieId, int SeriesId, int EpisodeId)> BazarrIds(string type, int? tmdbId, int? tvdbId, int? season, int? episode, CancellationToken ct)
    {
        if (type == "movie" && tmdbId > 0)
        {
            var m = (await Radarr.Get($"/movie?tmdbId={tmdbId}", ct).ConfigureAwait(false) as JsonArray)?.FirstOrDefault()
                    ?? throw new KeyNotFoundException("the movie is not in Radarr");
            return ("movie", (int)m["id"]!, 0, 0);
        }

        if (type == "episode" && tvdbId > 0 && season >= 0 && episode > 0)
        {
            var s = (await Sonarr.Get($"/series?tvdbId={tvdbId}", ct).ConfigureAwait(false) as JsonArray)?.FirstOrDefault()
                    ?? throw new KeyNotFoundException("the series is not in Sonarr");
            var ep = await FindEpisode(Sonarr, (int)s["id"]!, season!.Value, episode!.Value, ct).ConfigureAwait(false);
            return ("episode", 0, (int)s["id"]!, (int)ep["id"]!);
        }

        throw new ArgumentException("type must be movie (tmdbId) or episode (tvdbId, season, episode)");
    }

    public async Task<object> SubtitleSearch(string type, int? tmdbId, int? tvdbId, int? season, int? episode, CancellationToken ct)
    {
        var ids = await BazarrIds(type, tmdbId, tvdbId, season, episode, ct).ConfigureAwait(false);
        var path = ids.Kind == "movie" ? $"/providers/movies?radarrid={ids.MovieId}" : $"/providers/episodes?episodeid={ids.EpisodeId}";
        var res = await Bazarr.Get(path, ct).ConfigureAwait(false);
        var candidates = (res?["data"] as JsonArray ?? new JsonArray()).Where(c => c is not null).Select(c => new
        {
            id = (string?)c!["subtitle"],
            provider = (string?)c["provider"],
            language = (string?)c["language"],
            hearingImpaired = string.Equals(c["hearing_impaired"]?.ToString(), "True", StringComparison.OrdinalIgnoreCase),
            forced = string.Equals(c["forced"]?.ToString(), "True", StringComparison.OrdinalIgnoreCase),
            score = (double?)c["score"] ?? 0,
            releaseInfo = (c["release_info"] as JsonArray ?? new JsonArray()).Select(x => x?.ToString()).ToList(),
            originalFormat = string.Equals(c["original_format"]?.ToString(), "True", StringComparison.OrdinalIgnoreCase),
        }).ToList();
        return new { candidates };
    }

    public sealed class SubtitleDownload
    {
        public string Type { get; set; } = string.Empty;

        public int? TmdbId { get; set; }

        public int? TvdbId { get; set; }

        public int? Season { get; set; }

        public int? Episode { get; set; }

        public string Id { get; set; } = string.Empty;

        public string Provider { get; set; } = string.Empty;

        public bool HearingImpaired { get; set; }

        public bool Forced { get; set; }

        /// <summary>Bazarr's original_format flag of the candidate (spec 3.8).</summary>
        public bool OriginalFormat { get; set; }
    }

    /// <summary>Bazarr's view of one movie/episode: its subtitles and the profile's missing ones.</summary>
    private async Task<(JsonNode? Item, (string Kind, int MovieId, int SeriesId, int EpisodeId) Ids)> BazarrItem(string type, int? tmdbId, int? tvdbId, int? season, int? episode, CancellationToken ct)
    {
        var ids = await BazarrIds(type, tmdbId, tvdbId, season, episode, ct).ConfigureAwait(false);
        var path = ids.Kind == "movie" ? $"/movies?radarrid%5B%5D={ids.MovieId}" : $"/episodes?episodeid%5B%5D={ids.EpisodeId}";
        var item = (await Bazarr.Get(path, ct).ConfigureAwait(false))?["data"] is JsonArray { Count: > 0 } data ? data[0] : null;
        return (item, ids);
    }

    internal static List<string> Codes(JsonNode? list) =>
        (list as JsonArray ?? new JsonArray()).Select(s => (string?)s?["code2"]).Where(c => !string.IsNullOrEmpty(c)).Select(c => c!).Distinct().ToList();

    /// <summary>Spec 3.8: the languages the Bazarr profile wants that are there, and those missing.</summary>
    public async Task<object> SubtitleState(string type, int? tmdbId, int? tvdbId, int? season, int? episode, CancellationToken ct)
    {
        var (item, _) = await BazarrItem(type, tmdbId, tvdbId, season, episode, ct).ConfigureAwait(false);
        if (item is null)
        {
            throw new KeyNotFoundException("Bazarr does not know this title yet");
        }

        return new { have = Codes(item["subtitles"]), missing = Codes(item["missing_subtitles"]) };
    }

    public sealed class SubtitleSearchRequest
    {
        public string Type { get; set; } = string.Empty;

        public int? TmdbId { get; set; }

        public int? TvdbId { get; set; }

        public int? Season { get; set; }

        public int? Episode { get; set; }

        /// <summary>Languages (code2) to search; empty means every missing one.</summary>
        public List<string> Languages { get; set; } = new();
    }

    /// <summary>
    /// Spec 3.8: Bazarr's own automatic search (its "Search" button) for missing languages, in the
    /// background; the app asks SubtitleState afterwards.
    /// </summary>
    public async Task SubtitleSearchMissing(SubtitleSearchRequest r, CancellationToken ct)
    {
        var (item, ids) = await BazarrItem(r.Type, r.TmdbId, r.TvdbId, r.Season, r.Episode, ct).ConfigureAwait(false);
        if (item is null)
        {
            throw new KeyNotFoundException("Bazarr does not know this title yet");
        }

        var missing = (item["missing_subtitles"] as JsonArray ?? new JsonArray()).Where(m => m is not null).Select(m => m!).ToList();
        var want = r.Languages.Count == 0 ? missing.Select(m => (string?)m["code2"]).Where(c => c is not null).Select(c => c!).Distinct().ToList() : r.Languages;
        var bazarr = Bazarr;
        _ = Task.Run(async () =>
        {
            foreach (var lang in want)
            {
                // hi/forced as the profile asks for that language (from Bazarr's missing list).
                var m = missing.FirstOrDefault(x => string.Equals((string?)x["code2"], lang, StringComparison.OrdinalIgnoreCase));
                var form = new Dictionary<string, string>
                {
                    ["language"] = lang,
                    ["forced"] = string.Equals(m?["forced"]?.ToString(), "True", StringComparison.OrdinalIgnoreCase) ? "True" : "False",
                    ["hi"] = string.Equals(m?["hi"]?.ToString(), "True", StringComparison.OrdinalIgnoreCase) ? "True" : "False",
                };
                try
                {
                    if (ids.Kind == "movie")
                    {
                        form["radarrid"] = ids.MovieId.ToString(System.Globalization.CultureInfo.InvariantCulture);
                        await bazarr.PatchForm("/movies/subtitles", form, CancellationToken.None).ConfigureAwait(false);
                    }
                    else
                    {
                        form["seriesid"] = ids.SeriesId.ToString(System.Globalization.CultureInfo.InvariantCulture);
                        form["episodeid"] = ids.EpisodeId.ToString(System.Globalization.CultureInfo.InvariantCulture);
                        await bazarr.PatchForm("/episodes/subtitles", form, CancellationToken.None).ConfigureAwait(false);
                    }
                }
                catch (Exception e) when (e is UpstreamException or OperationCanceledException)
                {
                    _log.LogInformation("Tortugarr: Bazarr search for {Lang} found nothing or failed: {Message}", lang, e.Message);
                }
            }
        }, CancellationToken.None);
    }

    public async Task SubtitleGet(SubtitleDownload s, CancellationToken ct)
    {
        var ids = await BazarrIds(s.Type, s.TmdbId, s.TvdbId, s.Season, s.Episode, ct).ConfigureAwait(false);
        var form = new Dictionary<string, string>
        {
            ["hi"] = s.HearingImpaired ? "True" : "False",
            ["forced"] = s.Forced ? "True" : "False",
            ["original_format"] = s.OriginalFormat ? "True" : "False",
            ["provider"] = s.Provider,
            ["subtitle"] = s.Id,
        };
        if (ids.Kind == "movie")
        {
            form["radarrid"] = ids.MovieId.ToString(System.Globalization.CultureInfo.InvariantCulture);
            await Bazarr.PostForm("/providers/movies", form, ct).ConfigureAwait(false);
        }
        else
        {
            form["seriesid"] = ids.SeriesId.ToString(System.Globalization.CultureInfo.InvariantCulture);
            form["episodeid"] = ids.EpisodeId.ToString(System.Globalization.CultureInfo.InvariantCulture);
            await Bazarr.PostForm("/providers/episodes", form, ct).ConfigureAwait(false);
        }
    }
}

/// <summary>A feature switched off on this server; becomes 403 feature_off.</summary>
public sealed class FeatureOffException : Exception
{
    public FeatureOffException(string message)
        : base(message)
    {
    }
}

/// <summary>qBittorrent already has the release (spec 3.3); becomes 409 already_in_client. Nothing is deleted.</summary>
public sealed class AlreadyInClientException : Exception
{
    public AlreadyInClientException(string downloadId, string category, double progress, string state)
        : base($"qBittorrent already has this release (category {(category.Length > 0 ? category : "none")}, {Math.Floor(progress * 100)} %).")
    {
        DownloadId = downloadId;
        Category = category;
        Progress = progress;
        State = state;
    }

    public string DownloadId { get; }

    public string Category { get; }

    public double Progress { get; }

    public string State { get; }
}

/// <summary>The search found nothing and the service has no active indexer (spec 3.2); the job fails with no_indexers.</summary>
public sealed class NoIndexersException : Exception
{
    public NoIndexersException(string message)
        : base(message)
    {
    }
}

/// <summary>The release is no longer in the search results / the *arr's cache; becomes 409 search_expired.</summary>
public sealed class SearchExpiredException : Exception
{
    public SearchExpiredException()
        : base("search again - the release is no longer in Sonarr/Radarr's search cache")
    {
    }
}
