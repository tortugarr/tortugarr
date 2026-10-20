using System.Collections.Concurrent;
using System.Text.Json.Nodes;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.Movies;
using MediaBrowser.Controller.Entities.TV;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.IO;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>A delete that must not happen (spec 3.10); becomes 409 with this code. Nothing was changed.</summary>
public sealed class ConflictException : Exception
{
    public ConflictException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}

/// <summary>
/// Spec 3.10: deletes a movie, episode, season or series the way the original app does, then
/// scans only that library and clears Seerr - targeted for a movie or a whole series, through
/// the debounced full sync (3.11) for an episode or a season.
/// </summary>
public sealed class LibraryDeleteService
{
    private readonly ILibraryManager _library;
    private readonly IProviderManager _providers;
    private readonly IFileSystem _fileSystem;
    private readonly TortugarrService _svc;
    private readonly SeerrSync _sync;
    private readonly AdultLibraryService _adult;
    private readonly ILogger<LibraryDeleteService> _log;

    public LibraryDeleteService(ILibraryManager library, IProviderManager providers, IFileSystem fileSystem,
        TortugarrService svc, SeerrSync sync, AdultLibraryService adult, ILogger<LibraryDeleteService> log)
    {
        _adult = adult;
        _library = library;
        _providers = providers;
        _fileSystem = fileSystem;
        _svc = svc;
        _sync = sync;
        _log = log;
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    /// <summary>The same file, compared by name only (Sonarr/Radarr and Jellyfin see different mount paths).</summary>
    internal static bool SameFile(string? arrPath, string? jellyfinPath) =>
        !string.IsNullOrWhiteSpace(arrPath) && !string.IsNullOrWhiteSpace(jellyfinPath)
        && string.Equals(Path.GetFileName(arrPath.Replace('\\', '/')), Path.GetFileName(jellyfinPath.Replace('\\', '/')), StringComparison.OrdinalIgnoreCase);

    public async Task<object> DeleteAsync(Guid itemId, CancellationToken ct)
    {
        var item = _library.GetItemById(itemId) ?? throw new KeyNotFoundException("no such item in Jellyfin");
        var library = _library.GetCollectionFolders(item).OfType<CollectionFolder>().FirstOrDefault();
        if (library is not null && AdultLibraryService.IsAdult(library))
        {
            return await DeleteAdult(item, library, ct).ConfigureAwait(false);
        }

        string kind;
        int files;
        string seerr;
        var torrents = new List<string>(); // the title's downloads, read from the *arr history before the delete
        switch (item)
        {
            case Movie movie:
                // Marked before the delete: Radarr's webhook can make Jellyfin drop the item at once.
                _sync.Handled(item.Id);
                (files, var tmdb) = await DeleteMovie(movie, torrents, ct).ConfigureAwait(false);
                kind = "movie";
                seerr = await ClearSeerr("movie", tmdb, ct).ConfigureAwait(false);
                break;
            case Episode episode:
                files = await DeleteEpisodes(episode.Series, episode.ParentIndexNumber, episode, torrents, ct).ConfigureAwait(false);
                kind = "episode";
                seerr = QueueSync();
                break;
            case Season season:
                files = await DeleteEpisodes(season.Series, season.IndexNumber, null, torrents, ct).ConfigureAwait(false);
                kind = "season";
                seerr = QueueSync();
                break;
            case Series series:
                _sync.Handled(item.Id);
                (files, var tvTmdb) = await DeleteSeries(series, torrents, ct).ConfigureAwait(false);
                kind = "series";
                seerr = await ClearSeerr("tv", tvTmdb, ct).ConfigureAwait(false);
                break;
            default:
                throw new ArgumentException("only a movie, an episode, a season or a series can be deleted");
        }

        var torrentsRemoved = await RemoveTorrents(torrents, item is Movie ? Cfg.MovieCategory : Cfg.TvCategory, ct).ConfigureAwait(false);
        DropIfGone(item);
        if (library is not null)
        {
            // "Scan library" on that one library, not all of them.
            _providers.QueueRefresh(library.Id, new MetadataRefreshOptions(new DirectoryService(_fileSystem)) { IsAutomated = false }, RefreshPriority.High);
        }

        _log.LogInformation("Tortugarr: deleted {Kind} {Title} ({Files} file(s), {Torrents} torrent(s)), Seerr: {Seerr}", kind, item.Name, files, torrentsRemoved, seerr);
        return new { deleted = kind, title = item.Name, files, torrentsRemoved, libraryId = library?.Id.ToString("N"), seerr };
    }

    /// <summary>
    /// Removes Jellyfin's database entry for what this route just deleted, when its file or folder
    /// is gone from disk - only the entry, never a file. Jellyfin's own scan skips a library folder
    /// that has become empty (the last title of a library), and then the title would stay listed
    /// (lab: Tears of Steel and The Beverly Hillbillies in the existing libraries).
    /// </summary>
    private void DropIfGone(BaseItem item)
    {
        static bool Gone(BaseItem i) => !string.IsNullOrEmpty(i.Path) && !File.Exists(i.Path) && !Directory.Exists(i.Path);
        var targets = new List<BaseItem>();
        if (Gone(item))
        {
            targets.Add(item); // a series or season folder goes with its episodes
        }
        else if (item is Folder folder)
        {
            targets.AddRange(folder.GetRecursiveChildren().Where(c => c is Video && Gone(c)));
        }

        foreach (var t in targets)
        {
            try
            {
                _library.DeleteItem(t, new DeleteOptions { DeleteFileLocation = false }, true);
                _log.LogInformation("Tortugarr: removed {Name} from Jellyfin's list (its file is gone)", t.Name);
            }
            catch (Exception e)
            {
                _log.LogDebug(e, "Tortugarr: {Name} was already gone from Jellyfin", t.Name); // the scan was faster
            }
        }
    }

    /// <summary>
    /// The adult library has no Radarr/Sonarr behind it: the file belongs to a qBittorrent download
    /// (category adult) saved straight into the library. That download is removed with its files -
    /// Jellyfin itself cannot, its media folders are read-only - then the entry and the library scan.
    /// </summary>
    private async Task<object> DeleteAdult(BaseItem item, CollectionFolder library, CancellationToken ct)
    {
        if (Cfg.DownloadClientType != "qbittorrent" || string.IsNullOrEmpty(item.Path))
        {
            throw new ConflictException("not_managed", "the adult library's files can only be deleted through qBittorrent - nothing was deleted");
        }

        var qbit = _svc.Qbit;
        var torrent = (await qbit.List(Cfg.AdultCategory, ct).ConfigureAwait(false))
            .FirstOrDefault(t => t is not null && OwnsFile((string?)t["content_path"], item.Path));
        if (torrent is null)
        {
            throw new ConflictException("not_managed", "no download in qBittorrent holds this file - nothing was deleted");
        }

        await qbit.Delete((string)torrent["hash"]!, true, ct).ConfigureAwait(false);
        for (var i = 0; i < 20 && File.Exists(item.Path); i++)
        {
            await Task.Delay(500, ct).ConfigureAwait(false); // qBittorrent deletes the files in the background
        }

        DropIfGone(item);
        await _adult.RescanAsync().ConfigureAwait(false);
        _log.LogInformation("Tortugarr: deleted adult title {Title} (its download removed with its files)", item.Name);
        return new { deleted = "adult", title = item.Name, files = 1, torrentsRemoved = 1, libraryId = library.Id.ToString("N"), seerr = "not_applicable" };
    }

    /// <summary>The download's content path is the file itself, or a folder the file is in.</summary>
    internal static bool OwnsFile(string? contentPath, string file)
    {
        if (string.IsNullOrWhiteSpace(contentPath))
        {
            return false;
        }

        var c = contentPath.TrimEnd('/');
        return string.Equals(c, file, StringComparison.Ordinal) || file.StartsWith(c + "/", StringComparison.Ordinal);
    }

    /// <summary>
    /// The download ids (torrent hashes) to remove with a title. For episodes only a download that
    /// holds nothing but deleted episodes - a season pack other episodes came from stays.
    /// </summary>
    internal static List<string> DownloadsFor(JsonArray history, ICollection<int>? deletedEpisodes)
    {
        return history.Where(h => h is not null && !string.IsNullOrWhiteSpace((string?)h["downloadId"]))
            .GroupBy(h => ((string)h!["downloadId"]!).ToUpperInvariant())
            .Where(g => deletedEpisodes is null || g.All(h => deletedEpisodes.Contains((int?)h!["episodeId"] ?? -1)))
            .Select(g => g.Key).ToList();
    }

    /// <summary>Removes the title's torrents (with their download copies) - only from qBittorrent and only in the *arr's category.</summary>
    private async Task<int> RemoveTorrents(List<string> hashes, string category, CancellationToken ct)
    {
        if (hashes.Count == 0 || Cfg.DownloadClientType != "qbittorrent")
        {
            return 0;
        }

        try
        {
            var qbit = _svc.Qbit;
            var mine = (await qbit.ListAll(ct).ConfigureAwait(false))
                .Where(t => t is not null && (string?)t["category"] == category
                    && hashes.Contains(((string?)t["hash"] ?? string.Empty).ToUpperInvariant()))
                .Select(t => (string)t!["hash"]!).ToList();
            foreach (var h in mine)
            {
                await qbit.Delete(h, true, ct).ConfigureAwait(false);
            }

            return mine.Count;
        }
        catch (Exception e) when (e is UpstreamException or NotConfiguredException)
        {
            _log.LogWarning("Tortugarr: the title was deleted, but its torrent could not be removed: {Message}", e.Message);
            return 0;
        }
    }

    private async Task<(int Files, int? Tmdb)> DeleteMovie(Movie movie, List<string> torrents, CancellationToken ct)
    {
        if (!int.TryParse(movie.GetProviderId(MetadataProvider.Tmdb), out var tmdb))
        {
            throw new ConflictException("not_managed", "the movie has no TMDB id in Jellyfin, so it cannot be found in Radarr");
        }

        var radarr = _svc.Radarr;
        var found = (await radarr.Get($"/movie?tmdbId={tmdb}", ct).ConfigureAwait(false))?.AsArray().FirstOrDefault()
            ?? throw new ConflictException("not_managed", "the movie is not in Radarr (added by hand?) - nothing was deleted");
        var hasFile = (bool?)found["hasFile"] ?? false;
        if (!SameFile((string?)found["movieFile"]?["path"], movie.Path))
        {
            throw new ConflictException("file_mismatch", "Radarr's file is not the one in Jellyfin - nothing was deleted");
        }

        // Radarr deletes the history with the movie, so the downloads are read first.
        torrents.AddRange(DownloadsFor(await radarr.Get($"/history/movie?movieId={(int)found["id"]!}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray(), null));
        await radarr.Delete($"/movie/{(int)found["id"]!}?deleteFiles=true&addImportExclusion=false", ct).ConfigureAwait(false);
        return (hasFile ? 1 : 0, tmdb);
    }

    private async Task<JsonNode> FindSeries(Series? series, CancellationToken ct)
    {
        if (series is null || !int.TryParse(series.GetProviderId(MetadataProvider.Tvdb), out var tvdb))
        {
            throw new ConflictException("not_managed", "the series has no TVDB id in Jellyfin, so it cannot be found in Sonarr");
        }

        return (await _svc.Sonarr.Get($"/series?tvdbId={tvdb}", ct).ConfigureAwait(false))?.AsArray().FirstOrDefault()
            ?? throw new ConflictException("not_managed", "the series is not in Sonarr (added by hand?) - nothing was deleted");
    }

    /// <summary>One episode (file name checked) or a whole season: unmonitor first, then delete the files.</summary>
    private async Task<int> DeleteEpisodes(Series? series, int? seasonNumber, Episode? one, List<string> torrents, CancellationToken ct)
    {
        if (seasonNumber is null || (one is not null && one.IndexNumber is null))
        {
            throw new ConflictException("not_managed", "Jellyfin does not know the season/episode number - nothing was deleted");
        }

        var sonarr = _svc.Sonarr;
        var found = await FindSeries(series, ct).ConfigureAwait(false);
        var episodes = (await sonarr.Get($"/episode?seriesId={(int)found["id"]!}&seasonNumber={seasonNumber}", ct).ConfigureAwait(false))?.AsArray()
            .Where(e => e is not null).Select(e => e!).ToList() ?? new List<JsonNode>();
        if (one is not null)
        {
            episodes = episodes.Where(e => (int?)e["episodeNumber"] == one.IndexNumber).ToList();
        }

        if (episodes.Count == 0)
        {
            throw new ConflictException("not_managed", "Sonarr has no such episode - nothing was deleted");
        }

        var fileIds = episodes.Where(e => (bool?)e["hasFile"] == true).Select(e => (int?)e["episodeFileId"] ?? 0).Where(i => i > 0).Distinct().ToList();
        if (one is not null)
        {
            // Check before changing anything, as the app does for a single episode.
            var path = fileIds.Count == 1 ? (string?)(await sonarr.Get($"/episodefile/{fileIds[0]}", ct).ConfigureAwait(false))?["path"] : null;
            if (!SameFile(path, one.Path))
            {
                throw new ConflictException("file_mismatch", "Sonarr's file is not the one in Jellyfin - nothing was deleted");
            }
        }

        // Unmonitor first, or Sonarr would search for them again at once.
        var ids = episodes.Select(e => (int)e["id"]!).ToArray();
        torrents.AddRange(DownloadsFor(await sonarr.Get($"/history/series?seriesId={(int)found["id"]!}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray(), ids));
        await sonarr.Put("/episode/monitor", new { episodeIds = ids, monitored = false }, ct).ConfigureAwait(false);
        foreach (var id in fileIds)
        {
            await sonarr.Delete($"/episodefile/{id}", ct).ConfigureAwait(false);
        }

        return fileIds.Count;
    }

    private async Task<(int Files, int? Tmdb)> DeleteSeries(Series series, List<string> torrents, CancellationToken ct)
    {
        var found = await FindSeries(series, ct).ConfigureAwait(false);
        var files = (int?)found["statistics"]?["episodeFileCount"] ?? 0;
        int? tmdb = (int?)found["tmdbId"] is int t && t > 0 ? t
            : int.TryParse(series.GetProviderId(MetadataProvider.Tmdb), out var j) ? j : null;
        torrents.AddRange(DownloadsFor(await _svc.Sonarr.Get($"/history/series?seriesId={(int)found["id"]!}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray(), null));
        await _svc.Sonarr.Delete($"/series/{(int)found["id"]!}?deleteFiles=true&addImportListExclusion=false", ct).ConfigureAwait(false);
        return (files, tmdb);
    }

    private string QueueSync()
    {
        if (!SeerrSync.Configured)
        {
            return "not_configured";
        }

        _sync.Trigger();
        return "sync_queued";
    }

    /// <summary>"Clear Data" in Seerr for exactly this title.</summary>
    private async Task<string> ClearSeerr(string type, int? tmdb, CancellationToken ct)
    {
        if (!SeerrSync.Configured)
        {
            return "not_configured";
        }

        if (tmdb is null)
        {
            return "not_found";
        }

        try
        {
            var seerr = SeerrSync.Client(_svc);
            var mediaId = (int?)(await seerr.Get($"/{type}/{tmdb}", ct).ConfigureAwait(false))?["mediaInfo"]?["id"];
            if (mediaId is null)
            {
                return "not_found";
            }

            await seerr.Delete($"/media/{mediaId}", ct).ConfigureAwait(false);
            return "cleared";
        }
        catch (UpstreamException e)
        {
            _log.LogWarning("Tortugarr: clearing Seerr after a delete failed: {Message}", e.Message);
            _sync.Trigger(); // the safety net of 3.11 instead
            return "failed";
        }
    }
}

/// <summary>
/// Spec 3.11: after a movie, episode, season or series leaves Jellyfin by any other way, Seerr's
/// own availability-sync runs once - 2 minutes after the last removal, at the latest 10 minutes
/// after the first, so a burst of deletes gives one run.
/// </summary>
public sealed class SeerrSync
{
    internal static readonly TimeSpan Quiet = TimeSpan.FromMinutes(2);
    internal static readonly TimeSpan MaxWait = TimeSpan.FromMinutes(10);
    private readonly ConcurrentDictionary<Guid, DateTime> _handled = new();
    private readonly TortugarrService _svc;
    private readonly ILogger<SeerrSync> _log;
    private readonly object _gate = new();
    private DateTime? _first;
    private DateTime _last;
    private bool _waiting;

    public SeerrSync(TortugarrService svc, ILogger<SeerrSync> log)
    {
        _svc = svc;
        _log = log;
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    public static bool Configured => !string.IsNullOrWhiteSpace(Cfg.SeerrUrl) && !string.IsNullOrWhiteSpace(Cfg.SeerrApiKey);

    public static ArrClient Client(TortugarrService svc) => svc.Seerr;

    /// <summary>When the run is due: quiet for 2 minutes, but never more than 10 minutes after the first removal.</summary>
    internal static DateTime DueAt(DateTime first, DateTime last)
    {
        var quiet = last + Quiet;
        var cap = first + MaxWait;
        return quiet < cap ? quiet : cap;
    }

    /// <summary>A title cleared in Seerr by 3.10: its own removal (and its seasons and episodes) is not a reason to sync.</summary>
    public void Handled(Guid itemId) => _handled[itemId] = DateTime.UtcNow;

    private bool IsHandled(BaseItem item)
    {
        foreach (var old in _handled.Where(kv => DateTime.UtcNow - kv.Value > MaxWait).ToList())
        {
            _handled.TryRemove(old.Key, out _);
        }

        return _handled.ContainsKey(item.Id)
            || (item is Episode e && _handled.ContainsKey(e.SeriesId))
            || (item is Season s && _handled.ContainsKey(s.SeriesId));
    }

    public void OnRemoved(BaseItem item)
    {
        if (item is not (Movie or Episode or Season or Series) || IsHandled(item))
        {
            return;
        }

        var adult = Cfg.AdultSavePath.TrimEnd('/') + "/";
        if (!string.IsNullOrEmpty(item.Path) && item.Path.StartsWith(adult, StringComparison.Ordinal))
        {
            return; // Seerr knows nothing about the adult library
        }

        Trigger();
    }

    private int _recentQueued;

    /// <summary>
    /// After an import: Seerr's own "recently added" scan, 30 s later (Jellyfin has refreshed by
    /// then), so the request shows as available at once instead of at Seerr's next 5-minute run.
    /// Imports close together give one run.
    /// </summary>
    public void TriggerRecentlyAdded()
    {
        if (!Configured || Interlocked.Exchange(ref _recentQueued, 1) == 1)
        {
            return;
        }

        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(30)).ConfigureAwait(false);
                Interlocked.Exchange(ref _recentQueued, 0);
                await _svc.Seerr.Post("/settings/jobs/jellyfin-recently-added-scan/run", new JsonObject(), CancellationToken.None).ConfigureAwait(false);
                _log.LogInformation("Tortugarr: Seerr recently-added scan started after an import");
            }
            catch (Exception e)
            {
                Interlocked.Exchange(ref _recentQueued, 0);
                _log.LogWarning(e, "Tortugarr: starting Seerr's recently-added scan failed (its 5-minute run catches up)");
            }
        });
    }

    public void Trigger()
    {
        if (!Configured)
        {
            return;
        }

        lock (_gate)
        {
            var now = DateTime.UtcNow;
            _first ??= now;
            _last = now;
            if (_waiting)
            {
                return;
            }

            _waiting = true;
        }

        _ = Task.Run(RunWhenQuiet);
    }

    private async Task RunWhenQuiet()
    {
        while (true)
        {
            DateTime due;
            lock (_gate)
            {
                due = DueAt(_first!.Value, _last);
                if (DateTime.UtcNow >= due)
                {
                    _first = null;
                    _waiting = false;
                    break;
                }
            }

            await Task.Delay(TimeSpan.FromSeconds(5)).ConfigureAwait(false);
        }

        try
        {
            await _svc.Seerr.Post("/settings/jobs/availability-sync/run", new JsonObject(), CancellationToken.None).ConfigureAwait(false);
            _log.LogInformation("Tortugarr: Seerr availability-sync started after deletes");
        }
        catch (Exception e)
        {
            _log.LogWarning(e, "Tortugarr: starting Seerr's availability-sync failed (its hourly run catches up)");
        }
    }
}

/// <summary>Feeds Jellyfin's ItemRemoved event to SeerrSync.</summary>
public sealed class RemovedItemWatcher : Microsoft.Extensions.Hosting.IHostedService
{
    private readonly ILibraryManager _library;
    private readonly SeerrSync _sync;

    public RemovedItemWatcher(ILibraryManager library, SeerrSync sync)
    {
        _library = library;
        _sync = sync;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _library.ItemRemoved += OnRemoved;
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _library.ItemRemoved -= OnRemoved;
        return Task.CompletedTask;
    }

    private void OnRemoved(object? sender, ItemChangeEventArgs e) => _sync.OnRemoved(e.Item);
}
