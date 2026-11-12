using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Keeps downloads from dead-ending on a full drive.
///
/// 2026-11-05: Seerr adds every request to one fixed folder per type, and both pointed at E:,
/// which had 67 MB left. Requests from the app's lists landed there, and an episode of a series
/// already on E: could never import ("Not enough free space"): Sonarr always puts an episode in
/// its series' folder. Downloads started in the app were fine, they pick the roomiest drive.
///
/// Every 3 minutes this service
///  1. points Seerr's default series and movie folders at the root folder with the most free
///     space (the same choice the app's own downloads make), and
///  2. moves a series or movie whose import is held for lack of free space to that root, with
///     its files, so Sonarr or Radarr imports the download on its next check. Where a title's
///     files live does not matter to the app; Jellyfin shows them the same.
/// </summary>
public sealed class SpaceRescue : Microsoft.Extensions.Hosting.IHostedService
{
    private static readonly TimeSpan Every = TimeSpan.FromMinutes(3);
    private static readonly TimeSpan MoveAgainAfter = TimeSpan.FromHours(1);
    private readonly TortugarrService _svc;
    private readonly AdminNotice _notice;
    private readonly ILogger<SpaceRescue> _log;
    private readonly Dictionary<string, DateTimeOffset> _moved = new(StringComparer.Ordinal);
    private CancellationTokenSource? _stop;

    public SpaceRescue(TortugarrService svc, AdminNotice notice, ILogger<SpaceRescue> log)
    {
        _svc = svc;
        _notice = notice;
        _log = log;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _stop = new CancellationTokenSource();
        var token = _stop.Token;
        _ = Task.Run(async () =>
        {
            await Task.Delay(TimeSpan.FromMinutes(1), token).ConfigureAwait(false);
            while (!token.IsCancellationRequested)
            {
                foreach (var step in new Func<CancellationToken, Task>[] { SeerrFoldersAsync, CategoriesAsync, RescueAsync })
                {
                    try
                    {
                        await step(token).ConfigureAwait(false);
                    }
                    catch (OperationCanceledException) when (token.IsCancellationRequested)
                    {
                        return;
                    }
                    catch (Exception e)
                    {
                        _log.LogWarning(e, "Tortugarr: free-space check step failed");
                    }
                }

                await Task.Delay(Every, token).ConfigureAwait(false);
            }
        });
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _stop?.Cancel();
        return Task.CompletedTask;
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    private static bool Has(string url, string key) => !string.IsNullOrWhiteSpace(url) && !string.IsNullOrWhiteSpace(key);

    /// <summary>Seerr's default folders follow the roomiest root folder.</summary>
    private async Task SeerrFoldersAsync(CancellationToken ct)
    {
        var c = Cfg;
        if (!Has(c.SeerrUrl, c.SeerrApiKey))
        {
            return;
        }

        var seerr = _svc.Seerr;
        foreach (var (kind, arr, ok) in new[] { ("sonarr", _svc.Sonarr, Has(c.SonarrUrl, c.SonarrApiKey)), ("radarr", _svc.Radarr, Has(c.RadarrUrl, c.RadarrApiKey)) })
        {
            if (!ok)
            {
                continue;
            }

            var target = await TortugarrService.RootToFill(arr, ct).ConfigureAwait(false);
            foreach (var server in await seerr.Get($"/settings/{kind}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
            {
                if (server is not JsonObject s || WithFolder(s, target) is not { } changed)
                {
                    continue;
                }

                await seerr.Put($"/settings/{kind}/{(int?)s["id"] ?? 0}", changed, ct).ConfigureAwait(false);
                _log.LogInformation("Tortugarr: Seerr {Kind} \"{Name}\" now adds to {Target} (was {Old})", kind, (string?)s["name"], target, (string?)s["activeDirectory"]);
                await _notice.PostAsync("SeerrFolder" + kind, $"Seerr requests now go to {target}",
                    $"{(string?)s["activeDirectory"]} is no longer the drive to fill; new {(kind == "sonarr" ? "series" : "movies")} requested through Seerr go to {target}. Tortugarr fills the fullest drive first while it keeps {c.FillFloorBytes >> 30} GB free. Nothing to do.",
                    LogLevel.Information).ConfigureAwait(false);
            }
        }
    }

    /// <summary>
    /// 2026-11-12: only downloads started in the app moved the movie and series categories to the
    /// drive to fill; what Radarr, Sonarr and Seerr grabbed on their own kept going to the folder
    /// the category had last (H: with 24 GB left while I: had 1.7 TB). Keep both categories on the
    /// drive to fill.
    /// </summary>
    private async Task CategoriesAsync(CancellationToken ct)
    {
        var c = Cfg;
        await _svc.PointCategoryAtDriveToFill(c.MovieCategory, 0, ct, onlyWhenChanged: true).ConfigureAwait(false);
        await _svc.PointCategoryAtDriveToFill(c.TvCategory, 0, ct, onlyWhenChanged: true).ConfigureAwait(false);
    }

    /// <summary>The Seerr server settings with the default folder set to target, or null when it already is.</summary>
    internal static JsonObject? WithFolder(JsonObject server, string target)
    {
        var current = ((string?)server["activeDirectory"] ?? string.Empty).TrimEnd('/');
        if (string.Equals(current, target.TrimEnd('/'), StringComparison.Ordinal))
        {
            return null;
        }

        var changed = (JsonObject)server.DeepClone();
        changed.Remove("id"); // read-only: Seerr answers 400 when it is sent back (2026-11-05)
        changed["activeDirectory"] = target;
        if (((string?)changed["activeAnimeDirectory"] ?? string.Empty).TrimEnd('/') == current)
        {
            changed["activeAnimeDirectory"] = target; // it followed the default; keep it with it
        }

        return changed;
    }

    /// <summary>Series or movie ids whose download waits because their folder's drive is full.</summary>
    internal static List<int> HeldForSpace(JsonArray queueRecords, string idField) => queueRecords
        .Where(r => r is not null && (r["statusMessages"] as JsonArray ?? new JsonArray())
            .SelectMany(m => (m?["messages"] as JsonArray ?? new JsonArray()).Select(x => (string?)x ?? string.Empty).Append((string?)m?["title"] ?? string.Empty))
            .Any(t => t.Contains("free space", StringComparison.OrdinalIgnoreCase)))
        .Select(r => (int?)r![idField] ?? 0)
        .Where(id => id > 0).Distinct().ToList();

    private async Task RescueAsync(CancellationToken ct)
    {
        var c = Cfg;
        if (Has(c.SonarrUrl, c.SonarrApiKey))
        {
            await RescueAsync(_svc.Sonarr, "seriesId", "/series", "/series/editor", "seriesIds", ct).ConfigureAwait(false);
        }

        if (Has(c.RadarrUrl, c.RadarrApiKey))
        {
            await RescueAsync(_svc.Radarr, "movieId", "/movie", "/movie/editor", "movieIds", ct).ConfigureAwait(false);
        }
    }

    private async Task RescueAsync(ArrClient arr, string idField, string titlePath, string editorPath, string idsField, CancellationToken ct)
    {
        var queue = await arr.Get("/queue?pageSize=200", ct).ConfigureAwait(false);
        var held = HeldForSpace(queue?["records"] as JsonArray ?? new JsonArray(), idField);
        foreach (var id in held)
        {
            var key = arr.Name + id;
            if (_moved.TryGetValue(key, out var at) && DateTimeOffset.UtcNow - at < MoveAgainAfter)
            {
                continue; // a move of its files may still be running
            }

            var title = await arr.Get($"{titlePath}/{id}", ct).ConfigureAwait(false);
            var from = ((string?)title?["rootFolderPath"] ?? string.Empty).TrimEnd('/');
            var target = await TortugarrService.RootToFill(arr, ct, arr.Name == "Radarr" && TortugarrService.IsDocumentary(title), roomiest: true).ConfigureAwait(false);
            if (title is null || string.Equals(from, target.TrimEnd('/'), StringComparison.Ordinal))
            {
                continue; // already on the roomiest drive: moving would not help
            }

            await arr.Put(editorPath, new JsonObject
            {
                [idsField] = new JsonArray(id),
                ["rootFolderPath"] = target,
                ["moveFiles"] = true,
            }, ct).ConfigureAwait(false);
            _moved[key] = DateTimeOffset.UtcNow;
            var name = (string?)title["title"] ?? key;
            _log.LogWarning("Tortugarr: {Title} could not import for lack of space on {From} - moved to {Target}", name, from, target);
            await _notice.PostAsync("SpaceRescue" + key, $"{name} moved to a drive with space",
                $"The download could not be imported: {from} is full. Tortugarr moved {name} to {target}; {arr.Name} imports it within a few minutes. Nothing to do.",
                LogLevel.Information).ConfigureAwait(false);
        }
    }
}
