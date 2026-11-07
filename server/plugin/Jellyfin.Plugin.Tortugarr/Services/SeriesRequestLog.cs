using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>One series download started from the app.</summary>
public sealed class SeriesGrab
{
    public string UserId { get; set; } = string.Empty;

    public int TvdbId { get; set; }

    public int? TmdbId { get; set; }

    public string Title { get; set; } = string.Empty;

    public int? Season { get; set; }

    /// <summary>Null for a season pack.</summary>
    public int? Episode { get; set; }

    public string? DownloadId { get; set; }

    public DateTimeOffset At { get; set; }
}

/// <summary>
/// The series the app downloaded, for Seerr › Requests. A movie downloaded in the app files a
/// Seerr request; a series does not, on purpose (Seerr requests whole seasons, and one picked
/// episode became every season), so Requests never showed series (2026-11-07). The plugin keeps
/// its own list instead: the last 180 days, in a JSON file next to the limits ledger.
/// </summary>
public sealed class SeriesRequestLog
{
    internal static readonly TimeSpan Keep = TimeSpan.FromDays(180);
    internal const int MaxEntries = 2000;
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    private readonly object _gate = new();
    private readonly ILogger<SeriesRequestLog> _log;
    private readonly string? _path;

    public SeriesRequestLog(ILogger<SeriesRequestLog> log)
        : this(log, Plugin.Instance is { } p ? Path.Combine(p.DataFolderPath, "series-grabs.json") : null)
    {
    }

    internal SeriesRequestLog(ILogger<SeriesRequestLog> log, string? path)
    {
        _log = log;
        _path = path;
    }

    public void Add(SeriesGrab grab)
    {
        lock (_gate)
        {
            var all = Load().Where(g => grab.At - g.At < Keep).ToList();
            all.Add(grab);
            Save(all.OrderBy(g => g.At).TakeLast(MaxEntries).ToList());
        }
    }

    /// <summary>True once the list has taken in Sonarr's earlier grabs (done once per server).</summary>
    public bool Backfilled => _path is null || File.Exists(_path + ".backfilled");

    /// <summary>
    /// Adds earlier series grabs (from Sonarr's history) once, leaving out downloads already
    /// listed. 2026-11-07: the list started empty; the user wanted the recent series too.
    /// </summary>
    public int Backfill(IEnumerable<SeriesGrab> earlier, DateTimeOffset now)
    {
        lock (_gate)
        {
            if (Backfilled)
            {
                return 0;
            }

            var all = Load();
            var known = all.Select(g => g.DownloadId).Where(d => d is { Length: > 0 }).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var added = earlier.Where(g => g.DownloadId is not { Length: > 0 } d || !known.Contains(d)).Where(g => now - g.At < Keep).ToList();
            Save(all.Concat(added).OrderBy(g => g.At).TakeLast(MaxEntries).ToList());
            File.WriteAllText(_path + ".backfilled", now.ToString("O"));
            return added.Count;
        }
    }

    /// <summary>
    /// Sonarr's "grabbed" history as series grabs for one user (the administrator who opened the
    /// list: Sonarr does not know who asked). A season pack is one grab per episode in Sonarr; it
    /// becomes one grab of the season here.
    /// </summary>
    internal static List<SeriesGrab> FromSonarrHistory(JsonArray records, string userId, DateTimeOffset since) =>
        records
            .Where(r => r is not null && (string?)r["eventType"] is "grabbed" or "1")
            .Select(r => (
                Rec: r!,
                At: DateTimeOffset.TryParse((string?)r!["date"], out var d) ? d : DateTimeOffset.MinValue,
                Id: (string?)r["downloadId"] ?? string.Empty))
            .Where(x => x.At >= since && ((int?)x.Rec["series"]?["tvdbId"] ?? 0) > 0)
            .GroupBy(x => x.Id.Length > 0 ? x.Id : Guid.NewGuid().ToString("N"))
            .Select(group =>
            {
                var first = group.OrderBy(x => x.At).First();
                var episodes = group.Select(x => ((int?)x.Rec["episode"]?["seasonNumber"], (int?)x.Rec["episode"]?["episodeNumber"])).Distinct().ToList();
                var series = first.Rec["series"]!;
                return new SeriesGrab
                {
                    UserId = userId,
                    TvdbId = (int?)series["tvdbId"] ?? 0,
                    TmdbId = (int?)series["tmdbId"] is int t and > 0 ? t : null,
                    Title = (string?)series["title"] ?? string.Empty,
                    Season = episodes.Select(e => e.Item1).FirstOrDefault(s => s is not null),
                    Episode = episodes.Count == 1 ? episodes[0].Item2 : null,
                    DownloadId = first.Id.Length > 0 ? first.Id : null,
                    At = first.At,
                };
            })
            .ToList();

    public List<SeriesGrab> All()
    {
        lock (_gate)
        {
            return Load();
        }
    }

    /// <summary>
    /// One row per series and user, newest first: the user's own rows, or everyone's for an
    /// administrator. Downloading while one of its downloads is still in Sonarr's queue.
    /// </summary>
    internal static List<object> Rows(IEnumerable<SeriesGrab> grabs, Guid? onlyUser, ISet<string> queued, Func<string, string?> userName) =>
        grabs
            .Where(g => onlyUser is null || (Guid.TryParse(g.UserId, out var u) && u == onlyUser))
            .GroupBy(g => (g.TvdbId, g.UserId))
            .Select(group =>
            {
                var list = group.OrderByDescending(g => g.At).ToList();
                var last = list[0];
                return (At: last.At, Row: (object)new
                {
                    tvdbId = last.TvdbId,
                    tmdbId = list.Select(g => g.TmdbId).FirstOrDefault(t => t is > 0),
                    title = list.Select(g => g.Title).FirstOrDefault(t => t.Length > 0) ?? string.Empty,
                    userId = last.UserId,
                    userName = userName(last.UserId),
                    at = last.At,
                    firstAt = list[^1].At,
                    downloads = list.Count,
                    seasons = list.Where(g => g.Season is not null).Select(g => g.Season!.Value).Distinct().Order().ToList(),
                    downloading = list.Any(g => g.DownloadId is { Length: > 0 } d && queued.Contains(d)),
                });
            })
            .OrderByDescending(r => r.At)
            .Select(r => r.Row)
            .ToList();

    private List<SeriesGrab> Load()
    {
        if (_path is null || !File.Exists(_path))
        {
            return new List<SeriesGrab>();
        }

        try
        {
            return JsonSerializer.Deserialize<List<SeriesGrab>>(File.ReadAllText(_path), Options) ?? new List<SeriesGrab>();
        }
        catch (Exception e) when (e is JsonException or IOException)
        {
            _log.LogWarning("Tortugarr: series request list unreadable, starting over: {Error}", e.Message);
            return new List<SeriesGrab>();
        }
    }

    private void Save(List<SeriesGrab> all)
    {
        if (_path is null)
        {
            return;
        }

        var tmp = _path + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(all, Options));
        File.Move(tmp, _path, true);
    }
}
