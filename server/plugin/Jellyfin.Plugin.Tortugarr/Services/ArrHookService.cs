using System.Text.Json.Nodes;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.IO;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Spec 3.12: Radarr's/Sonarr's webhook after an import, rename or delete. Refreshes only the
/// nearest existing item for each path in the payload - the way Jellyfin's folder watcher does,
/// without its delay - instead of scanning every library.
/// </summary>
public sealed class ArrHookService
{
    private readonly ILibraryManager _library;
    private readonly IProviderManager _providers;
    private readonly IFileSystem _fileSystem;
    private readonly SeerrSync _seerr;
    private readonly TortugarrService _svc;
    private readonly ILogger<ArrHookService> _log;
    private readonly NotifyService _notify;

    public ArrHookService(ILibraryManager library, IProviderManager providers, IFileSystem fileSystem, SeerrSync seerr, TortugarrService svc, ILogger<ArrHookService> log, NotifyService notify)
    {
        _notify = notify;
        _library = library;
        _providers = providers;
        _fileSystem = fileSystem;
        _seerr = seerr;
        _svc = svc;
        _log = log;
    }

    /// <summary>The paths a webhook payload names, the most precise (file paths) first.</summary>
    internal static List<string> HookPaths(JsonNode body)
    {
        var paths = new List<string>();
        void Add(JsonNode? n)
        {
            var p = (string?)n;
            if (!string.IsNullOrWhiteSpace(p) && p.StartsWith('/') && !paths.Contains(p))
            {
                paths.Add(p);
            }
        }

        void AddAll(JsonNode? arr)
        {
            if (arr is JsonArray a)
            {
                foreach (var x in a)
                {
                    Add(x?["path"]);
                }
            }
        }

        Add(body["movieFile"]?["path"]);
        Add(body["episodeFile"]?["path"]);
        AddAll(body["episodeFiles"]);
        AddAll(body["renamedMovieFiles"]);
        AddAll(body["renamedEpisodeFiles"]);
        AddAll(body["deletedFiles"]);
        Add(body["movie"]?["folderPath"]);
        Add(body["series"]?["path"]);
        return paths;
    }

    public async Task HandleAsync(JsonNode body)
    {
        var evt = (string?)body["eventType"] ?? string.Empty;
        if (evt == "Test")
        {
            return;
        }

        if (evt == "MovieAdded")
        {
            // Nothing on disk yet, so nothing for Jellyfin: only a documentary's folder.
            if ((int?)body["movie"]?["id"] is { } id)
            {
                await _svc.PlaceDocumentaryAsync(id, CancellationToken.None).ConfigureAwait(false);
            }

            return;
        }

        if (evt == "Download")
        {
            _seerr.TriggerRecentlyAdded(); // an import (or upgrade): Seerr shows it as available soon
            if (_notify.Enabled && body["isUpgrade"]?.GetValue<bool>() != true)
            {
                _ = Task.Run(() => NotifyReadyAsync(body));
            }
        }

        var items = HookPaths(body).Select(Affected).Where(i => i is not null).Select(i => i!).DistinctBy(i => i.Id).ToList();
        if (items.Count == 0)
        {
            // Not in any library Jellyfin knows: the old behaviour, a scan of everything.
            _log.LogInformation("Tortugarr: {Event} hook with no path in a library - full library scan", evt);
            await _library.ValidateMediaLibrary(new Progress<double>(), CancellationToken.None).ConfigureAwait(false);
            return;
        }

        foreach (var item in items)
        {
            _log.LogInformation("Tortugarr: {Event} hook - refreshing {Name} ({Path}) only", evt, item.Name, item.Path);
            _providers.QueueRefresh(item.Id, new MetadataRefreshOptions(new DirectoryService(_fileSystem)), RefreshPriority.High);
        }
    }

    /// <summary>"Ready to watch" (G) to whoever started the download, else whoever asked Seerr for it.</summary>
    private async Task NotifyReadyAsync(JsonNode body)
    {
        try
        {
            var downloadId = (string?)body["downloadId"];
            var owners = new List<Guid>();
            if (_notify.WhoGrabbed(downloadId) is { } grabber)
            {
                owners.Add(grabber);
            }
            else if (await SeerrRequesterAsync(body).ConfigureAwait(false) is { } requester)
            {
                owners.Add(requester);
            }

            if (body["movie"] is { } movie)
            {
                var title = (string?)movie["title"] ?? "A film";
                var year = (int?)movie["year"];
                var name = year > 0 ? $"{title} ({year})" : title;
                await _notify.ReadyAsync(owners, $"Ready: {name}", $"{name} is ready to watch.").ConfigureAwait(false);
            }
            else if (body["series"] is { } series && body["episodes"] is JsonArray eps)
            {
                foreach (var season in eps.Where(e => e is not null).GroupBy(e => (int?)e!["seasonNumber"] ?? 0))
                {
                    _notify.EpisodesReady(owners, (string?)series["title"] ?? "A series", season.Key,
                        season.Select(e => (int?)e!["episodeNumber"] ?? 0).Where(n => n > 0));
                }
            }
        }
        catch (Exception e)
        {
            _log.LogDebug(e, "Tortugarr: ready notification skipped");
        }
    }

    /// <summary>The Jellyfin user behind the Seerr request for this title, when there is one.</summary>
    private async Task<Guid?> SeerrRequesterAsync(JsonNode body)
    {
        var tmdb = (int?)body["movie"]?["tmdbId"];
        var tvdb = (int?)body["series"]?["tvdbId"];
        if (tmdb is null && tvdb is null)
        {
            return null;
        }

        var page = await _svc.Seerr.Get("/request?take=100&sort=added&filter=all", CancellationToken.None, 15).ConfigureAwait(false);
        var hit = (page?["results"] as JsonArray ?? new JsonArray()).FirstOrDefault(r =>
            (tmdb is not null && (int?)r?["media"]?["tmdbId"] == tmdb && (string?)r?["type"] == "movie")
            || (tvdb is not null && (int?)r?["media"]?["tvdbId"] == tvdb && (string?)r?["type"] == "tv"));
        return Guid.TryParse((string?)hit?["requestedBy"]?["jellyfinUserId"], out var id) ? id : null;
    }

    /// <summary>
    /// The nearest item for a path that still exists on disk (Jellyfin's FileRefresher logic).
    /// Null for paths outside every library.
    /// </summary>
    private BaseItem? Affected(string path)
    {
        BaseItem? item = null;
        while (item is null && !string.IsNullOrEmpty(path))
        {
            item = _library.FindByPath(path, null);
            path = Path.GetDirectoryName(path) ?? string.Empty;
        }

        while (item is not null && !Directory.Exists(item.Path) && !File.Exists(item.Path))
        {
            item = item.GetOwner() ?? item.GetParent();
        }

        return item is AggregateFolder or UserRootFolder ? null : item;
    }
}
