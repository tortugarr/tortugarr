using System.Text.Json.Nodes;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Spec 3.14: a series as Sonarr sees it (with the queue), and the app's season switch
/// (missing_episodes.dart setSeasonMonitoring) done on the server.
/// </summary>
public sealed class SeriesService
{
    private readonly TortugarrService _svc;

    public SeriesService(TortugarrService svc)
    {
        _svc = svc;
    }

    private static Dictionary<string, bool> SeasonMonitoring(JsonNode series) =>
        (series["seasons"] as JsonArray ?? new JsonArray()).Where(s => s is not null)
            .ToDictionary(s => ((int?)s!["seasonNumber"] ?? 0).ToString(System.Globalization.CultureInfo.InvariantCulture), s => (bool?)s!["monitored"] ?? false);

    private static bool Aired(JsonNode e, DateTimeOffset now) =>
        DateTimeOffset.TryParse((string?)e["airDateUtc"], out var d) && d <= now;

    public async Task<object> GetAsync(int tvdbId, CancellationToken ct)
    {
        var sonarr = _svc.Sonarr;
        if ((await sonarr.Get($"/series?tvdbId={tvdbId}", ct).ConfigureAwait(false) as JsonArray)?.FirstOrDefault() is not { } series)
        {
            return new { inSonarr = false };
        }

        var id = (int)series["id"]!;
        var episodes = (await sonarr.Get($"/episode?seriesId={id}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
            .Where(e => e is not null).Select(e => e!).ToList();
        var queue = await sonarr.Get("/queue?pageSize=1000&includeUnknownSeriesItems=false", ct).ConfigureAwait(false);
        var queued = (queue?["records"] as JsonArray ?? new JsonArray())
            .Where(r => (int?)r?["seriesId"] == id).Select(r => (int?)r!["episodeId"] ?? 0).Where(e => e > 0).ToHashSet();
        var seasons = (series["seasons"] as JsonArray ?? new JsonArray()).Where(s => s is not null).Select(s => s!)
            .OrderBy(s => (int?)s["seasonNumber"] ?? 0)
            .Select(s =>
            {
                var n = (int?)s["seasonNumber"] ?? 0;
                return new
                {
                    seasonNumber = n,
                    monitored = (bool?)s["monitored"] ?? false,
                    episodes = episodes.Where(e => (int?)e["seasonNumber"] == n).OrderBy(e => (int?)e["episodeNumber"] ?? 0).Select(e => new
                    {
                        episodeId = (int)e["id"]!,
                        seasonNumber = n,
                        episodeNumber = (int?)e["episodeNumber"] ?? 0,
                        title = (string?)e["title"],
                        airDateUtc = (string?)e["airDateUtc"],
                        hasFile = (bool?)e["hasFile"] ?? false,
                        monitored = (bool?)e["monitored"] ?? false,
                        queued = queued.Contains((int)e["id"]!),
                    }).ToList(),
                };
            }).ToList();
        return new
        {
            inSonarr = true,
            arrId = id,
            title = (string?)series["title"],
            year = (int?)series["year"],
            monitored = (bool?)series["monitored"] ?? false,
            seasonMonitoring = SeasonMonitoring(series),
            queuedEpisodeIds = queued.OrderBy(x => x).ToList(),
            seasons,
        };
    }

    public sealed class SeasonRequest
    {
        public bool Monitored { get; set; }

        public bool Search { get; set; }
    }

    public async Task<object> SetSeasonAsync(int tvdbId, int seasonNumber, SeasonRequest req, CancellationToken ct)
    {
        var sonarr = _svc.Sonarr;
        var series = (await _svc.EnsureSeries(sonarr, tvdbId, ct).ConfigureAwait(false)).DeepClone().AsObject();
        var id = (int)series["id"]!;
        var seasons = series["seasons"] as JsonArray ?? new JsonArray();
        var season = seasons.FirstOrDefault(s => (int?)s?["seasonNumber"] == seasonNumber) as JsonObject
                     ?? throw new KeyNotFoundException($"the series has no season {seasonNumber}");
        season["monitored"] = req.Monitored;
        // The app's rule: the series is monitored while any season is; new seasons are not followed.
        series["monitored"] = seasons.Any(s => (bool?)s?["monitored"] == true);
        series["monitorNewItems"] = "none";
        var saved = await sonarr.Put($"/series/{id}", series, ct).ConfigureAwait(false) ?? series;

        var searchQueued = false;
        string? message = null;
        if (req.Monitored && !req.Search)
        {
            // Switched on without a search: only future episodes are followed, old ones are neither
            // fetched nor upgraded.
            var now = DateTimeOffset.UtcNow;
            var aired = (await sonarr.Get($"/episode?seriesId={id}&seasonNumber={seasonNumber}", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray())
                .Where(e => e is not null && Aired(e!, now)).Select(e => (int)e!["id"]!).ToArray();
            if (aired.Length > 0)
            {
                await sonarr.Put("/episode/monitor", new { episodeIds = aired, monitored = false }, ct).ConfigureAwait(false);
            }
        }
        else if (req.Monitored && req.Search)
        {
            try
            {
                await sonarr.Post("/command", new { name = "SeasonSearch", seriesId = id, seasonNumber }, ct).ConfigureAwait(false);
                searchQueued = true;
            }
            catch (UpstreamException e)
            {
                message = $"season monitored, but no search: {e.Message}";
            }
        }

        return new { arrId = id, seasonNumber, monitored = req.Monitored, seasonMonitoring = SeasonMonitoring(saved), searchQueued, message };
    }
}
