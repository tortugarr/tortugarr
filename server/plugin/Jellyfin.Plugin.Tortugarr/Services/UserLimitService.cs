using System.Text.Json;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>A limit stopped a search result or a grab: 403 with this code.</summary>
public sealed class LimitException : Exception
{
    public LimitException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    /// <summary>limit_exceeded (file too big) or quota_exceeded (weekly count used up).</summary>
    public string Code { get; }
}

/// <summary>One grab by a limited user, kept for the rolling week.</summary>
public sealed class UserGrab
{
    /// <summary>Lets a grab that surely did not happen give its place back.</summary>
    public string Id { get; set; } = Guid.NewGuid().ToString("N");

    public string UserId { get; set; } = string.Empty;

    public string Type { get; set; } = string.Empty;

    /// <summary>Movies (1) or episodes (1, or the season's episodes for a season pack).</summary>
    public int Count { get; set; }

    public long Bytes { get; set; }

    public DateTimeOffset At { get; set; }
}

/// <summary>
/// Per-user size and weekly limits for non-administrators (user, 2026-10-25: the daughter may
/// fetch at most 2.5 GB per movie and 950 MB per episode). Administrators are never limited.
/// The limits live in the plugin configuration; the grabs of the last week in a JSON file.
/// </summary>
public sealed class UserLimitService
{
    internal static readonly TimeSpan Week = TimeSpan.FromDays(7);
    private readonly object _gate = new();
    private readonly ILogger<UserLimitService> _log;
    private readonly string? _ledgerPath;

    public UserLimitService(ILogger<UserLimitService> log)
        : this(log, Plugin.Instance is { } p ? Path.Combine(p.DataFolderPath, "user-grabs.json") : null)
    {
    }

    internal UserLimitService(ILogger<UserLimitService> log, string? ledgerPath)
    {
        _log = log;
        _ledgerPath = ledgerPath;
    }

    private static PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new PluginConfiguration();

    /// <summary>The user's limit when it is switched on, else null.</summary>
    public UserLimit? For(Guid userId) => Find(Cfg.UserLimits, userId) is { Enabled: true } l ? l : null;

    internal static UserLimit? Find(IEnumerable<UserLimit> limits, Guid userId) =>
        limits.FirstOrDefault(l => Guid.TryParse(l.UserId, out var id) && id == userId);

    /// <summary>Movies and episodes the user grabbed in the last 7 days.</summary>
    public (int Movies, int Episodes) Used(Guid userId, DateTimeOffset now)
    {
        lock (_gate)
        {
            return Count(Load(), userId, now);
        }
    }

    public void Record(Guid userId, string type, int count, long bytes, DateTimeOffset now) =>
        Add(new UserGrab { UserId = userId.ToString("N"), Type = type, Count = count, Bytes = bytes, At = now });

    /// <summary>
    /// Checks the weekly count and takes the place in one step, so two grabs at once cannot both
    /// pass. Throws <see cref="LimitException"/> (quota_exceeded) when the count is used up.
    /// </summary>
    public string Reserve(Guid userId, UserLimit limit, string type, int count, long bytes, DateTimeOffset now)
    {
        lock (_gate)
        {
            var grabs = Load().Where(g => now - g.At < Week).ToList();
            var episodes = type == "movie" ? 0 : count;
            if (QuotaProblem(limit, Count(grabs, userId, now), type, episodes) is string used)
            {
                throw new LimitException("quota_exceeded", used);
            }

            var grab = new UserGrab { UserId = userId.ToString("N"), Type = type, Count = count, Bytes = bytes, At = now };
            grabs.Add(grab);
            Save(grabs);
            return grab.Id;
        }
    }

    /// <summary>Gives a reserved place back: the grab surely did not happen.</summary>
    public void Release(string id)
    {
        lock (_gate)
        {
            Save(Load().Where(g => g.Id != id).ToList());
        }
    }

    /// <summary>
    /// After a failed grab: could Radarr/Sonarr still have taken it? Yes when we stopped waiting
    /// (timeout, cancelled request); no when they answered with a refusal.
    /// </summary>
    internal static bool MayHaveGrabbed(Exception e) =>
        e is OperationCanceledException
        || (e is UpstreamException u && u.Message.Contains("no answer within", StringComparison.Ordinal));

    private void Add(UserGrab grab)
    {
        lock (_gate)
        {
            var grabs = Load().Where(g => grab.At - g.At < Week).ToList();
            grabs.Add(grab);
            Save(grabs);
        }
    }

    /// <summary>What the app shows a limited user: the limits and what is used this week.</summary>
    public object Describe(UserLimit l, Guid userId, DateTimeOffset now)
    {
        var (movies, episodes) = Used(userId, now);
        return new
        {
            maxMovieMb = l.MaxMovieMb,
            maxEpisodeMb = l.MaxEpisodeMb,
            moviesPerWeek = l.MoviesPerWeek,
            episodesPerWeek = l.EpisodesPerWeek,
            moviesUsed = movies,
            episodesUsed = episodes,
        };
    }

    /// <summary>Saves (adds or replaces) a user's limits.</summary>
    public void Set(Guid userId, UserLimit limit)
    {
        var plugin = Plugin.Instance ?? throw new NotConfiguredException("the plugin is not loaded");
        limit.UserId = userId.ToString("N");
        limit.MaxMovieMb = Math.Max(0, limit.MaxMovieMb);
        limit.MaxEpisodeMb = Math.Max(0, limit.MaxEpisodeMb);
        limit.MoviesPerWeek = Math.Max(0, limit.MoviesPerWeek);
        limit.EpisodesPerWeek = Math.Max(0, limit.EpisodesPerWeek);
        plugin.Configuration.UserLimits = plugin.Configuration.UserLimits
            .Where(l => !(Guid.TryParse(l.UserId, out var id) && id == userId))
            .Append(limit)
            .ToArray();
        plugin.SaveConfiguration();
    }

    // ------------------------------------------------------------------ pure rules (tested)

    /// <summary>How many episodes a grab is: 0 for a movie, 1 for an episode, the season's count for a pack.</summary>
    internal static int Episodes(string type, int seasonEpisodes) => type switch
    {
        "movie" => 0,
        "season" => seasonEpisodes,
        _ => 1,
    };

    /// <summary>Why this file is too big for the user, or null. A season pack is judged per episode.</summary>
    internal static string? SizeProblem(UserLimit l, string type, long size, int seasonEpisodes)
    {
        if (type == "movie")
        {
            return l.MaxMovieMb > 0 && size > Mb(l.MaxMovieMb) ? $"Over your size limit ({Show(l.MaxMovieMb)} per movie)" : null;
        }

        if (l.MaxEpisodeMb <= 0)
        {
            return null;
        }

        if (type == "season")
        {
            if (seasonEpisodes <= 0)
            {
                return "Over your size limit (the season's episode count is unknown)";
            }

            return size > Mb(l.MaxEpisodeMb) * seasonEpisodes ? $"Over your size limit ({Show(l.MaxEpisodeMb)} per episode)" : null;
        }

        return size > Mb(l.MaxEpisodeMb) ? $"Over your size limit ({Show(l.MaxEpisodeMb)} per episode)" : null;
    }

    /// <summary>Why this grab would go over the weekly count, or null.</summary>
    internal static string? QuotaProblem(UserLimit l, (int Movies, int Episodes) used, string type, int seasonEpisodes)
    {
        if (type == "movie")
        {
            return l.MoviesPerWeek > 0 && used.Movies + 1 > l.MoviesPerWeek
                ? $"You have used {used.Movies} of {l.MoviesPerWeek} movies this week"
                : null;
        }

        var want = Episodes(type, seasonEpisodes);
        return l.EpisodesPerWeek > 0 && used.Episodes + want > l.EpisodesPerWeek
            ? $"You have used {used.Episodes} of {l.EpisodesPerWeek} episodes this week"
            : null;
    }

    internal static (int Movies, int Episodes) Count(IEnumerable<UserGrab> grabs, Guid userId, DateTimeOffset now)
    {
        var mine = grabs.Where(g => Guid.TryParse(g.UserId, out var id) && id == userId && now - g.At < Week).ToList();
        return (mine.Where(g => g.Type == "movie").Sum(g => g.Count), mine.Where(g => g.Type != "movie").Sum(g => g.Count));
    }

    private static long Mb(int mb) => mb * 1024L * 1024;

    /// <summary>950 MB, 2.5 GB.</summary>
    internal static string Show(int mb) =>
        mb >= 1024 ? $"{(mb / 1024.0).ToString("0.#", System.Globalization.CultureInfo.InvariantCulture)} GB" : $"{mb} MB";

    // ------------------------------------------------------------------ ledger file

    private List<UserGrab> Load()
    {
        if (_ledgerPath is null || !File.Exists(_ledgerPath))
        {
            return new List<UserGrab>();
        }

        try
        {
            return JsonSerializer.Deserialize<List<UserGrab>>(File.ReadAllText(_ledgerPath)) ?? new List<UserGrab>();
        }
        catch (Exception e) when (e is IOException or JsonException)
        {
            _log.LogWarning("Tortugarr: could not read {Path}: {Message}", _ledgerPath, e.Message);
            return new List<UserGrab>();
        }
    }

    private void Save(List<UserGrab> grabs)
    {
        if (_ledgerPath is null)
        {
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(_ledgerPath)!);
        var tmp = _ledgerPath + ".tmp";
        File.WriteAllText(tmp, JsonSerializer.Serialize(grabs));
        File.Move(tmp, _ledgerPath, true);
    }
}
