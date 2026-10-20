using System.Text.Json.Nodes;
using Jellyfin.Data.Enums;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Entities.TV;
using MediaBrowser.Controller.Library;
using MediaBrowser.Model.Entities;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Spec 3.15: the data behind the app's free-space dialog (duplicate torrents, titles with size,
/// last played and favorite) and its check before a download (space_guard_service.dart). The
/// staleness rules and the order stay in the app.
/// </summary>
public sealed class SpaceService
{
    private readonly TortugarrService _svc;
    private readonly ILibraryManager _library;
    private readonly IUserManager _users;
    private readonly IUserDataManager _userData;

    public SpaceService(TortugarrService svc, ILibraryManager library, IUserManager users, IUserDataManager userData)
    {
        _svc = svc;
        _library = library;
        _users = users;
        _userData = userData;
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    private static string? Unix(JsonNode? t) =>
        (long?)t is long s && s > 0 ? DateTimeOffset.FromUnixTimeSeconds(s).UtcDateTime.ToString("o") : null;

    /// <summary>Spec 3.15: the app's rule, needed = size + buffer, shortfall = needed + pending - free.</summary>
    internal static (long Needed, long Shortfall) Rule(long bytes, long buffer, long pending, long free)
    {
        var needed = bytes + buffer;
        return (needed, Math.Max(0, needed + pending - free));
    }

    public async Task<object> CheckAsync(long bytes, CancellationToken ct)
    {
        if (bytes < 0)
        {
            throw new ArgumentException("bytes must be 0 or more");
        }

        var qbit = _svc.Qbit;
        // With several download folders the next download goes to the roomiest (see
        // TortugarrService.PointCategoryAtRoomiestDrive); qBittorrent itself only reports its
        // default folder's drive.
        var roomiest = TortugarrService.RoomiestDownloadRoot(
            TortugarrService.ParseDownloadRoots(Cfg.DownloadRoots), TortugarrService.FreeBytes);
        var free = roomiest?.Free
            ?? await qbit.FreeSpace(ct).ConfigureAwait(false)
            ?? throw new UpstreamException("qBittorrent", "no free-space figure");
        var pending = (await qbit.ListAll(ct).ConfigureAwait(false))
            .Where(t => t is not null && ((double?)t["progress"] ?? 0) < 1).Sum(t => (long?)t!["amount_left"] ?? 0);
        var buffer = Math.Max(0, Cfg.SpaceBufferBytes);
        var (needed, shortfall) = Rule(bytes, buffer, pending, free);
        return new { freeBytes = free, pendingBytes = pending, bufferBytes = buffer, neededBytes = needed, shortfallBytes = shortfall, enough = shortfall == 0 };
    }

    /// <summary>Finished torrents in the movie/TV category that no *arr queue holds any more.</summary>
    private async Task<List<JsonNode>> Duplicates(CancellationToken ct)
    {
        var inQueue = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var arr in Arrs())
        {
            var q = await arr.Get("/queue?pageSize=1000", ct).ConfigureAwait(false);
            foreach (var r in q?["records"] as JsonArray ?? new JsonArray())
            {
                if ((string?)r?["downloadId"] is { Length: > 0 } d)
                {
                    inQueue.Add(d);
                }
            }
        }

        return (await _svc.Qbit.ListAll(ct).ConfigureAwait(false))
            .Where(t => t is not null
                && ((string?)t["category"] == Cfg.MovieCategory || (string?)t["category"] == Cfg.TvCategory)
                && ((double?)t["progress"] ?? 0) >= 1
                && !inQueue.Contains((string?)t["hash"] ?? string.Empty))
            .Select(t => t!).OrderBy(t => (long?)t["added_on"] ?? 0).ToList();
    }

    private IEnumerable<ArrClient> Arrs()
    {
        var c = Cfg;
        if (!string.IsNullOrWhiteSpace(c.RadarrUrl) && !string.IsNullOrWhiteSpace(c.RadarrApiKey))
        {
            yield return _svc.Radarr;
        }

        if (!string.IsNullOrWhiteSpace(c.SonarrUrl) && !string.IsNullOrWhiteSpace(c.SonarrApiKey))
        {
            yield return _svc.Sonarr;
        }
    }

    public async Task DeleteDuplicateAsync(string hash, CancellationToken ct)
    {
        var dup = (await Duplicates(ct).ConfigureAwait(false))
            .FirstOrDefault(t => string.Equals((string?)t["hash"], hash, StringComparison.OrdinalIgnoreCase))
            ?? throw new KeyNotFoundException("not a duplicate (unknown, still downloading, queued, or another category)");
        await _svc.Qbit.Delete((string)dup["hash"]!, true, ct).ConfigureAwait(false);
    }

    public async Task<object> CandidatesAsync(CancellationToken ct)
    {
        var free = await _svc.Qbit.FreeSpace(ct).ConfigureAwait(false);
        var duplicates = (await Duplicates(ct).ConfigureAwait(false)).Select(t => new
        {
            hash = ((string?)t["hash"])?.ToUpperInvariant(),
            name = (string?)t["name"],
            category = (string?)t["category"],
            bytes = (long?)t["size"] ?? (long?)t["total_size"] ?? 0,
            added = Unix(t["added_on"]),
        }).ToList();

        // Jellyfin's movies and series by provider id, for the ids 3.10 deletes with.
        var items = _library.GetItemList(new InternalItemsQuery { IncludeItemTypes = new[] { BaseItemKind.Movie, BaseItemKind.Series }, Recursive = true });
        var byTmdb = new Dictionary<int, BaseItem>();
        var byTvdb = new Dictionary<int, BaseItem>();
        foreach (var i in items)
        {
            if (i is Series && int.TryParse(i.GetProviderId(MetadataProvider.Tvdb), out var tv))
            {
                byTvdb.TryAdd(tv, i);
            }
            else if (i is not Series && int.TryParse(i.GetProviderId(MetadataProvider.Tmdb), out var tm))
            {
                byTmdb.TryAdd(tm, i);
            }
        }

        var users = _users.GetUsers().ToList();
        var titles = new List<object>();
        var c = Cfg;
        if (!string.IsNullOrWhiteSpace(c.RadarrUrl) && !string.IsNullOrWhiteSpace(c.RadarrApiKey))
        {
            foreach (var m in await _svc.Radarr.Get("/movie", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
            {
                var bytes = (long?)m?["sizeOnDisk"] ?? 0;
                if (m is null || bytes <= 0)
                {
                    continue;
                }

                var tmdb = (int?)m["tmdbId"] ?? 0;
                byTmdb.TryGetValue(tmdb, out var jf);
                var (last, fav) = Activity(jf, users);
                titles.Add(new { kind = "movie", title = (string?)m["title"], year = (int?)m["year"], arrId = (int)m["id"]!, tmdbId = (int?)tmdb, tvdbId = (int?)null, bytes, jellyfinId = jf?.Id.ToString("N"), added = (string?)m["added"], lastPlayed = last, favorite = fav });
            }
        }

        if (!string.IsNullOrWhiteSpace(c.SonarrUrl) && !string.IsNullOrWhiteSpace(c.SonarrApiKey))
        {
            foreach (var s in await _svc.Sonarr.Get("/series", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
            {
                var bytes = (long?)s?["statistics"]?["sizeOnDisk"] ?? 0;
                if (s is null || bytes <= 0)
                {
                    continue;
                }

                var tvdb = (int?)s["tvdbId"] ?? 0;
                byTvdb.TryGetValue(tvdb, out var jf);
                var (last, fav) = Activity(jf, users);
                titles.Add(new { kind = "series", title = (string?)s["title"], year = (int?)s["year"], arrId = (int)s["id"]!, tmdbId = (int?)s["tmdbId"], tvdbId = (int?)tvdb, bytes, jellyfinId = jf?.Id.ToString("N"), added = (string?)s["added"], lastPlayed = last, favorite = fav });
            }
        }

        return new { freeBytes = free, totalBytes = (long?)null, duplicates, titles };
    }

    /// <summary>
    /// Last played by any user (for a series: any of its episodes, played or half-watched) and
    /// whether any user marked the title a favorite.
    /// </summary>
    private (string? LastPlayed, bool Favorite) Activity(BaseItem? item, List<Jellyfin.Database.Implementations.Entities.User> users)
    {
        if (item is null)
        {
            return (null, false);
        }

        var watched = item is Series series ? series.GetRecursiveChildren(i => i is Episode).ToList() : new List<BaseItem> { item };
        DateTime? last = null;
        var favorite = false;
        foreach (var user in users)
        {
            favorite |= _userData.GetUserData(user, item)?.IsFavorite == true;
            foreach (var w in watched)
            {
                var d = _userData.GetUserData(user, w);
                if (d?.LastPlayedDate is DateTime p && (d.Played || d.PlaybackPositionTicks > 0) && (last is null || p > last))
                {
                    last = p;
                }
            }
        }

        return (last is DateTime l ? DateTime.SpecifyKind(l, DateTimeKind.Utc).ToString("o") : null, favorite);
    }
}
