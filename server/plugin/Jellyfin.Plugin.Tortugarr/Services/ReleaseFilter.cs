using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Jellyfin.Plugin.Tortugarr.Configuration;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>One release from Sonarr/Radarr's interactive search, reduced to what the filters and the app need.</summary>
public sealed class ArrRelease
{
    public string Guid { get; init; } = string.Empty;

    public int IndexerId { get; init; }

    public string Indexer { get; init; } = string.Empty;

    public string Title { get; init; } = string.Empty;

    public long Size { get; init; }

    public int? Seeders { get; init; }

    public int? Leechers { get; init; }

    public string Protocol { get; init; } = string.Empty;

    public string DownloadUrl { get; init; } = string.Empty;

    public string MagnetUrl { get; init; } = string.Empty;

    public DateTimeOffset? PublishDate { get; init; }

    public string Quality { get; init; } = string.Empty;

    public int Resolution { get; init; }

    public List<string> Languages { get; init; } = new();

    public List<string> Rejections { get; init; } = new();

    public bool SeasonPack { get; init; }

    /// <summary>The torrent's info hash when the indexer gives it (used for already_in_client, spec 3.3).</summary>
    public string InfoHash { get; init; } = string.Empty;

    /// <summary>Reads one entry of GET /api/v3/release (Sonarr v4 / Radarr v6).</summary>
    public static ArrRelease FromJson(JsonNode n)
    {
        static string S(JsonNode? x) => x?.GetValue<object>()?.ToString() ?? string.Empty;
        var rejections = new List<string>();
        if (n["rejections"] is JsonArray rj)
        {
            foreach (var r in rj)
            {
                // Plain strings, or objects with a "reason" in some versions.
                var text = r is JsonObject o ? S(o["reason"]) : S(r);
                if (text.Length > 0)
                {
                    rejections.Add(text);
                }
            }
        }

        var languages = new List<string>();
        if (n["languages"] is JsonArray la)
        {
            foreach (var l in la)
            {
                var name = S(l?["name"]);
                if (name.Length > 0)
                {
                    languages.Add(name);
                }
            }
        }

        DateTimeOffset? published = DateTimeOffset.TryParse(S(n["publishDate"]), out var d) ? d : null;
        return new ArrRelease
        {
            Guid = S(n["guid"]),
            IndexerId = (int?)n["indexerId"] ?? 0,
            Indexer = S(n["indexer"]),
            Title = S(n["title"]),
            Size = (long?)n["size"] ?? 0,
            Seeders = (int?)n["seeders"],
            Leechers = (int?)n["leechers"],
            Protocol = S(n["protocol"]),
            DownloadUrl = S(n["downloadUrl"]),
            MagnetUrl = S(n["magnetUrl"]),
            PublishDate = published,
            Quality = S(n["quality"]?["quality"]?["name"]),
            Resolution = (int?)n["quality"]?["quality"]?["resolution"] ?? 0,
            Languages = languages,
            Rejections = rejections,
            SeasonPack = (bool?)n["fullSeason"] ?? false,
            InfoHash = S(n["infoHash"]),
        };
    }
}

/// <summary>What the app gets for one release (spec 3.2).</summary>
public sealed class ReleaseDto
{
    public string Guid { get; init; } = string.Empty;

    public int IndexerId { get; init; }

    public string Indexer { get; init; } = string.Empty;

    public string Title { get; init; } = string.Empty;

    public long Size { get; init; }

    public int? Seeders { get; init; }

    public int? Leechers { get; init; }

    public string Protocol { get; init; } = string.Empty;

    public string Quality { get; init; } = string.Empty;

    public List<string> Languages { get; init; } = new();

    public DateTimeOffset? PublishDate { get; init; }

    public bool SeasonPack { get; init; }

    /// <summary>Below the quality minimum, kept only because the search asked for SD (allowSd).</summary>
    public bool Sd { get; init; }

    public bool Approved { get; init; }

    public bool Recommended { get; init; }

    public List<string> Rejections { get; init; } = new();

    /// <summary>Server side only (spec 3.3), never sent to the app.</summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public string InfoHash { get; init; } = string.Empty;
}

/// <summary>The app's release filters (spec section 4), applied on the server.</summary>
public sealed class ReleaseFilter
{
    private static readonly Regex UpgradeRejection =
        new(@"existing file|not an upgrade|does not allow upgrades", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private readonly PluginConfiguration _cfg;
    private readonly Regex _junk;
    private readonly Regex _quality;
    private readonly Regex _hard;
    private readonly Regex _bannedInTitle;
    private readonly string[] _banned;

    public ReleaseFilter(PluginConfiguration cfg)
    {
        _cfg = cfg;
        _junk = new Regex(cfg.JunkRegex, RegexOptions.IgnoreCase);
        _quality = new Regex(cfg.QualityRegex, RegexOptions.IgnoreCase);
        _hard = new Regex(cfg.HardRejectionRegex, RegexOptions.IgnoreCase);
        _banned = cfg.BannedExtensions.Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(e => e.Trim().ToLowerInvariant()).Where(e => e.StartsWith('.')).ToArray();
        var alt = string.Join('|', _banned.Select(e => Regex.Escape(e.TrimStart('.'))));
        // ".exe" as a file ending inside a title: followed by the end, a space, ] ) - _ or another dot.
        _bannedInTitle = new Regex(@"\.(" + alt + @")(?=$|[\s\]\)\-_.])", RegexOptions.IgnoreCase);
    }

    /// <summary>Why a release is dropped by 4.1 (null = it passes). <paramref name="isMovie"/> picks the size minimum.</summary>
    public string? Rule41(ArrRelease r, bool isMovie, DateTimeOffset? homeRelease, bool allowSd = false)
    {
        if (!r.Protocol.Equals("torrent", StringComparison.OrdinalIgnoreCase)
            && !r.Protocol.Equals("bittorrent", StringComparison.OrdinalIgnoreCase))
        {
            return "not a torrent";
        }

        if (string.IsNullOrWhiteSpace(r.DownloadUrl) && string.IsNullOrWhiteSpace(r.MagnetUrl))
        {
            return "no magnet link or download URL";
        }

        if (_junk.IsMatch(r.Title))
        {
            return "junk words (cam/telesync/executable)";
        }

        var sd = !_quality.IsMatch(r.Title);
        if (sd && !allowSd)
        {
            return "below the quality minimum";
        }

        // An SD release kept by allowSd has its own, lower minimum.
        var min = sd ? (isMovie ? _cfg.MinSdMovieBytes : _cfg.MinSdEpisodeBytes) : (isMovie ? _cfg.MinMovieBytes : _cfg.MinEpisodeBytes);
        if (r.Size > 0 && r.Size < min)
        {
            return "too small";
        }

        if (_bannedInTitle.IsMatch(r.Title) || HasBannedUrlEnding(r.DownloadUrl))
        {
            return "banned file type";
        }

        if (isMovie && IsEarly(r, homeRelease))
        {
            return "early";
        }

        return null;
    }

    public bool IsEarly(ArrRelease r, DateTimeOffset? homeRelease) =>
        homeRelease is not null && r.PublishDate is not null
        && r.PublishDate.Value < homeRelease.Value.AddDays(-_cfg.EarlyReleaseDays);

    public bool IsVideo(string fileName, long size)
    {
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        return size >= _cfg.MinVideoBytes
               && _cfg.VideoExtensions.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                   .Any(e => e.Equals(ext, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>What the last Apply dropped, by reason (for the search log line).</summary>
    public Dictionary<string, int> Dropped { get; } = new();

    private void Drop(string why) => Dropped[why] = Dropped.TryGetValue(why, out var n) ? n + 1 : 1;

    /// <summary>The drop counts as "reason n, reason n", largest first; "none" when nothing was dropped.</summary>
    public string DroppedText() => Dropped.Count == 0 ? "none"
        : string.Join(", ", Dropped.OrderByDescending(d => d.Value).Select(d => $"{d.Key} {d.Value}"));

    /// <summary>Applies 4.1-4.4. <paramref name="kind"/> is movie, episode or season.</summary>
    public (List<ReleaseDto> Releases, int DroppedEarly) Apply(IEnumerable<ArrRelease> input, string kind, DateTimeOffset? homeRelease, bool allowSd = false)
    {
        var isMovie = kind == "movie";
        var kept = new List<ReleaseDto>();
        var early = 0;
        foreach (var r in input)
        {
            var why = Rule41(r, isMovie, homeRelease, allowSd);
            var sd = allowSd && !_quality.IsMatch(r.Title);
            if (why == "early")
            {
                early++;
                continue;
            }

            if (why is not null)
            {
                Drop(why);
                continue;
            }

            if (r.Rejections.FirstOrDefault(x => _hard.IsMatch(x)) is { } hard)
            {
                Drop(hard); // Sonarr's/Radarr's own reason, e.g. "Unknown Series"
                continue; // 4.2
            }

            var rejections = r.Rejections;
            if (rejections.Any(x => UpgradeRejection.IsMatch(x)))
            {
                if (!r.SeasonPack)
                {
                    Drop("already there / not an upgrade");
                    continue; // 4.3: a single episode or a movie that is already there
                }

                rejections = rejections.Where(x => !UpgradeRejection.IsMatch(x)).ToList(); // a pack fills the gaps
            }

            kept.Add(new ReleaseDto
            {
                Guid = r.Guid,
                IndexerId = r.IndexerId,
                Indexer = r.Indexer,
                Title = r.Title,
                Size = r.Size,
                Seeders = r.Seeders,
                Leechers = r.Leechers,
                Protocol = r.Protocol,
                Quality = r.Quality,
                Languages = r.Languages,
                PublishDate = r.PublishDate,
                SeasonPack = r.SeasonPack,
                Sd = sd,
                Approved = rejections.Count == 0,
                Recommended = rejections.Count == 0,
                Rejections = rejections,
                InfoHash = r.InfoHash,
            });
        }

        // 4.4: packs first (season requests), recommended first, resolution, seeders.
        var res = new Dictionary<string, int>();
        foreach (var k in kept)
        {
            res[k.Guid + k.IndexerId] = ResolutionRank(k);
        }

        var sorted = kept
            .OrderByDescending(k => kind == "season" && k.SeasonPack)
            .ThenByDescending(k => k.Recommended)
            .ThenByDescending(k => res[k.Guid + k.IndexerId])
            .ThenByDescending(k => k.Seeders ?? 0)
            .ToList();
        return (sorted, early);
    }

    private static int ResolutionRank(ReleaseDto r)
    {
        var t = r.Title + " " + r.Quality;
        if (t.Contains("2160", StringComparison.Ordinal))
        {
            return 3;
        }

        if (t.Contains("1080", StringComparison.Ordinal))
        {
            return 2;
        }

        return t.Contains("720", StringComparison.Ordinal) ? 1 : 0;
    }

    // ------------------------------------------------------------------ adult (spec 4.7)

    /// <summary>Why an adult release is dropped (null = it passes): the safety checks only.</summary>
    public string? AdultRule(ArrRelease r)
    {
        if (!r.Protocol.Equals("torrent", StringComparison.OrdinalIgnoreCase)
            && !r.Protocol.Equals("bittorrent", StringComparison.OrdinalIgnoreCase))
        {
            return "not a torrent";
        }

        if (string.IsNullOrWhiteSpace(r.DownloadUrl) && string.IsNullOrWhiteSpace(r.MagnetUrl))
        {
            return "no magnet link or download URL";
        }

        if (Regex.IsMatch(r.Title, _cfg.AdultUnsafeRegex, RegexOptions.IgnoreCase))
        {
            return "executable words";
        }

        if (_bannedInTitle.IsMatch(r.Title) || HasBannedUrlEnding(r.DownloadUrl))
        {
            return "banned file type";
        }

        return r.Size > 0 && r.Size < _cfg.AdultMinBytes ? "too small" : null;
    }

    /// <summary>The searches the app makes: the whole phrase, then each word on its own.</summary>
    public static List<string> AdultQueries(string query)
    {
        var phrase = string.Join(' ', query.Split(' ', StringSplitOptions.RemoveEmptyEntries));
        var list = new List<string> { phrase };
        foreach (var w in Words(phrase))
        {
            if (!list.Contains(w, StringComparer.OrdinalIgnoreCase))
            {
                list.Add(w);
            }
        }

        return list;
    }

    /// <summary>Merges the results of all queries (one per guid+indexer), keeps the safe ones and
    /// ranks them by how many query words the title holds, then by seeders.</summary>
    public List<(ArrRelease Release, int MatchedWords)> AdultMerge(string query, IEnumerable<ArrRelease> results)
    {
        var words = Words(query).Select(w => w.ToLowerInvariant()).Distinct().ToList();
        var seen = new HashSet<string>();
        var kept = new List<(ArrRelease, int)>();
        foreach (var r in results)
        {
            if (!seen.Add(r.Guid + "|" + r.IndexerId) || AdultRule(r) is not null)
            {
                continue;
            }

            var titleWords = new HashSet<string>(Words(r.Title).Select(w => w.ToLowerInvariant()));
            kept.Add((r, words.Count(titleWords.Contains)));
        }

        return kept.OrderByDescending(k => k.Item2).ThenByDescending(k => k.Item1.Seeders ?? 0).ToList();
    }

    private static IEnumerable<string> Words(string s) =>
        Regex.Split(s, @"[^\p{L}\p{N}]+").Where(w => w.Length > 0);

    private bool HasBannedUrlEnding(string url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        var path = Uri.TryCreate(url, UriKind.Absolute, out var u) ? u.AbsolutePath : url.Split('?')[0];
        return _banned.Any(e => path.EndsWith(e, StringComparison.OrdinalIgnoreCase));
    }
}
