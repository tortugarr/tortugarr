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
