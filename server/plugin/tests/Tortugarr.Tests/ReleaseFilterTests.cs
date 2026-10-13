using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class ReleaseFilterTests
{
    private static readonly ReleaseFilter F = new(new PluginConfiguration());
    private const long MB = 1024 * 1024;

    private static ArrRelease R(string title, long size = 2000 * MB, string protocol = "torrent", string url = "http://idx/dl/1",
        DateTimeOffset? published = null, bool pack = false, int seeders = 10, params string[] rejections) => new()
    {
        Guid = title, IndexerId = 1, Title = title, Size = size, Protocol = protocol, DownloadUrl = url,
        PublishDate = published, SeasonPack = pack, Seeders = seeders, Rejections = rejections.ToList(),
    };

    [Theory]
    [InlineData("Movie.2024.1080p.WEB-DL.x264-GRP", null)]
    [InlineData("Movie.2024.HDCAM.x264", "junk words (cam/telesync/executable)")]
    [InlineData("Movie 2024 TS XviD", "junk words (cam/telesync/executable)")]
    [InlineData("Movie.2024.1080p.WEB.exe", "junk words (cam/telesync/executable)")]
    [InlineData("Movie.2024.x264-GRP", "below the quality minimum")]
    [InlineData("Movie.2024.DVDRip.x264", null)]
    [InlineData("Movie.2024.1080p.WEB-DL.DTS-HD", null)]
    [InlineData("Movie.2024.1080p.WEB-DL.rar", "banned file type")]
    [InlineData("Movie.2024.1080p.BluRay [www.site.com]", "banned file type")]
    public void Rule41_title_checks(string title, string? expected) =>
        Assert.Equal(expected, F.Rule41(R(title), isMovie: true, homeRelease: null));

    [Fact]
    public void Size_minimum_depends_on_kind_and_ignores_unknown_size()
    {
        Assert.Equal("too small", F.Rule41(R("Movie.2024.1080p.WEB-DL", 600 * MB), true, null));
        Assert.Null(F.Rule41(R("Show.S01E01.1080p.WEB-DL", 600 * MB), false, null));
        Assert.Equal("too small", F.Rule41(R("Show.S01E01.1080p.WEB-DL", 150 * MB), false, null));
        Assert.Null(F.Rule41(R("Movie.2024.1080p.WEB-DL", 0), true, null));
    }

    [Fact]
    public void Torrent_only_with_a_link()
    {
        Assert.Equal("not a torrent", F.Rule41(R("Movie.2024.1080p.WEB-DL", protocol: "usenet"), true, null));
        Assert.Equal("no magnet link or download URL", F.Rule41(R("Movie.2024.1080p.WEB-DL", url: ""), true, null));
        Assert.Equal("banned file type", F.Rule41(R("Movie.2024.1080p.WEB-DL", url: "http://idx/files/movie.zip?x=1"), true, null));
    }

    [Fact]
    public void Movies_published_long_before_the_home_release_are_counted_and_dropped()
    {
        var home = new DateTimeOffset(2026, 11, 15, 0, 0, 0, TimeSpan.Zero);
        var list = new[]
        {
            R("Movie.2026.1080p.WEBRip.x265", published: home.AddDays(-30)),   // early -> dropped
            R("Movie.2026.1080p.WEB-DL.x264", published: home.AddDays(-1)),    // within 2 days -> kept
            R("Movie.2026.1080p.WEB-DL.H264", published: null),                // no date -> kept
        };
        var (kept, early) = F.Apply(list, "movie", home);
        Assert.Equal(1, early);
        Assert.Equal(2, kept.Count);
        Assert.DoesNotContain(kept, k => k.Title.Contains("WEBRip"));
    }

    [Fact]
    public void Hard_rejections_drop_and_soft_ones_stay_as_not_recommended()
    {
        var list = new[]
        {
            R("Show.S01E02.1080p.WEB-DL", rejections: "Release is in the blocklist"),
            R("Show.S01E02.720p.WEB-DL", rejections: "Not enough seeders: 0. Minimum seeders: 1"),
            R("Show.S01E02.2160p.WEB-DL", rejections: "Quality for release is outside the profile"),
            R("Show.S01E02.1080p.WEBRip"),
        };
        var (kept, _) = F.Apply(list, "episode", null);
        Assert.Equal(new[] { "Show.S01E02.1080p.WEBRip", "Show.S01E02.2160p.WEB-DL" }, kept.Select(k => k.Title));
        Assert.True(kept[0].Recommended);
        Assert.False(kept[1].Recommended);
        Assert.Single(kept[1].Rejections);
    }

    [Fact]
    public void Existing_file_drops_a_single_episode_but_keeps_a_season_pack_without_that_reason()
    {
        var list = new[]
        {
            R("Show.S01E03.1080p.WEB-DL", rejections: "Existing file on disk is of equal or higher preference"),
            R("Show.S01.1080p.WEB-DL", pack: true, rejections: "Existing file on disk is of equal or higher preference"),
        };
        var (kept, _) = F.Apply(list, "season", null);
        var pack = Assert.Single(kept);
        Assert.True(pack.SeasonPack);
        Assert.Empty(pack.Rejections);
        Assert.True(pack.Recommended);
    }

    [Fact]
    public void Order_is_packs_first_for_a_season_then_recommended_then_resolution_then_seeders()
    {
        var list = new[]
        {
            R("Show.S01E01.720p.WEB-DL", seeders: 500),
            R("Show.S01E01.2160p.WEB-DL", seeders: 5),
            R("Show.S01E01.1080p.WEB-DL", seeders: 50),
            R("Show.S01E01.1080p.WEBRip", seeders: 80),
            R("Show.S01.1080p.WEB-DL", pack: true, seeders: 1),
            R("Show.S01E01.2160p.WEBRip", seeders: 999, rejections: "Quality for release is outside the profile"),
        };
        var (kept, _) = F.Apply(list, "season", null);
        Assert.Equal(new[]
        {
            "Show.S01.1080p.WEB-DL",
            "Show.S01E01.2160p.WEB-DL",
            "Show.S01E01.1080p.WEBRip",
            "Show.S01E01.1080p.WEB-DL",
            "Show.S01E01.720p.WEB-DL",
            "Show.S01E01.2160p.WEBRip",
        }, kept.Select(k => k.Title));
    }

    [Theory]
    [InlineData("Movie.mkv", 60, true)]
    [InlineData("movie.MP4", 60, true)]
    [InlineData("Sample.mkv", 10, false)]
    [InlineData("Movie.exe", 900, false)]
    [InlineData("disc.vob", 600, true)]
    [InlineData("readme.txt", 1, false)]
    public void Video_means_a_video_extension_and_at_least_50_MB(string name, long sizeMb, bool expected) =>
        Assert.Equal(expected, F.IsVideo(name, sizeMb * MB));
}

public class AdultFilterTests
{
    private static readonly ReleaseFilter F = new(new PluginConfiguration());
    private const long MB = 1024 * 1024;

    private static ArrRelease R(string title, long size = 300 * MB, int seeders = 5, string guid = "", string url = "http://idx/dl/1", string protocol = "torrent") => new()
    {
        Guid = guid.Length > 0 ? guid : title, IndexerId = 7, Title = title, Size = size, Seeders = seeders, DownloadUrl = url, Protocol = protocol,
    };

    [Theory]
    [InlineData("Some Clip 1080p", null)]
    [InlineData("Some Clip SD", null)]                 // no quality minimum for this library
    [InlineData("Some Clip CAM", null)]                // no CAM/TS rule either
    [InlineData("Some Clip exe", "executable words")]
    [InlineData("Some Clip.scr", "executable words")]
    [InlineData("Some Clip.zip", "banned file type")]
    public void Safety_checks_only(string title, string? expected) => Assert.Equal(expected, F.AdultRule(R(title)));

    [Fact]
    public void Twenty_megabytes_minimum_torrent_only()
    {
        Assert.Equal("too small", F.AdultRule(R("Some Clip", 10 * MB)));
        Assert.Null(F.AdultRule(R("Some Clip", 0)));
        Assert.Equal("not a torrent", F.AdultRule(R("Some Clip", protocol: "usenet")));
        Assert.Equal("no magnet link or download URL", F.AdultRule(R("Some Clip", url: "")));
    }

    [Fact]
    public void Queries_are_the_phrase_then_each_word()
    {
        Assert.Equal(new[] { "red blue  green".Replace("  ", " "), "red", "blue", "green" }, ReleaseFilter.AdultQueries("red  blue green"));
        Assert.Equal(new[] { "one" }, ReleaseFilter.AdultQueries("one"));
    }

    [Fact]
    public void Merged_once_per_release_ranked_by_matched_words_then_seeders()
    {
        var results = new[]
        {
            R("Red Clip", seeders: 100, guid: "a"),
            R("Red Blue Clip", seeders: 3, guid: "b"),
            R("Red Blue Clip", seeders: 3, guid: "b"),          // same release from another query
            R("Blue Clip", seeders: 50, guid: "c"),
            R("Red Blue Clip exe", seeders: 999, guid: "d"),    // unsafe
            R("Other", seeders: 999, guid: "e"),
        };
        var ranked = F.AdultMerge("red blue", results);
        Assert.Equal(new[] { "b", "a", "c", "e" }, ranked.Select(x => x.Release.Guid));
        Assert.Equal(new[] { 2, 1, 1, 0 }, ranked.Select(x => x.MatchedWords));
    }
}

public class DroppedCountTests
{
    [Fact]
    public void Drops_are_counted_by_reason()
    {
        var f = new ReleaseFilter(new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration());
        var r = new[]
        {
            new ArrRelease { Guid = "1", Title = "Movie.2024.1080p.WEB-DL.x264-GRP", Size = 2000L * 1024 * 1024, Protocol = "torrent", DownloadUrl = "http://x/1" },
            new ArrRelease { Guid = "2", Title = "Movie.2024.1080p.WEB-DL.x264-GRP", Size = 100L * 1024 * 1024, Protocol = "torrent", DownloadUrl = "http://x/2" },
            new ArrRelease { Guid = "3", Title = "Movie.2024.1080p.WEB-DL.x264-GRP", Size = 2000L * 1024 * 1024, Protocol = "usenet", DownloadUrl = "http://x/3" },
        };
        var (kept, _) = f.Apply(r, "movie", null);
        Assert.Single(kept);
        Assert.Equal("too small 1, not a torrent 1", f.DroppedText());
    }
}

public class AllowSdTests
{
    private static ArrRelease R(string title) => new() { Guid = title, Title = title, Size = 2000L * 1024 * 1024, Protocol = "torrent", DownloadUrl = "http://x/" + title };

    [Fact]
    public void Sd_is_dropped_by_default_and_counted()
    {
        var f = new ReleaseFilter(new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration());
        var (kept, _) = f.Apply(new[] { R("Bonanza.S01E01.480p.TVRip.XviD-GRP") }, "episode", null);
        Assert.Empty(kept);
        Assert.Equal(1, f.Dropped["below the quality minimum"]);
    }

    [Fact]
    public void Sd_is_kept_and_marked_when_allowed_while_other_filters_still_apply()
    {
        var f = new ReleaseFilter(new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration());
        var (kept, _) = f.Apply(new[] { R("Bonanza.S01E01.480p.TVRip.XviD-GRP"), R("Bonanza.S01E01.HDCAM.XviD-GRP"), R("Bonanza.S01E01.1080p.WEB-DL-GRP") }, "episode", null, allowSd: true);
        Assert.Equal(2, kept.Count);
        Assert.True(kept.Single(k => k.Title.Contains("480p")).Sd);
        Assert.False(kept.Single(k => k.Title.Contains("1080p")).Sd);
        Assert.Equal(1, f.Dropped["junk words (cam/telesync/executable)"]);
    }
}

public class SdSizeAndReasonTests
{
    private const long MB = 1024L * 1024;

    private static ArrRelease R(string title, long size, params string[] rejections) => new()
    {
        Guid = title, Title = title, Size = size, Protocol = "torrent", DownloadUrl = "http://x/" + title, Rejections = rejections.ToList(),
    };

    [Fact]
    public void Sd_episodes_have_their_own_lower_minimum()
    {
        var f = new ReleaseFilter(new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration());
        var (kept, _) = f.Apply(new[] { R("Show.S01E01.480p.x264-GRP", 120 * MB), R("Show.S01E02.480p.x264-GRP", 50 * MB), R("Show.S01E03.1080p.WEB-DL-GRP", 120 * MB) }, "episode", null, allowSd: true);
        Assert.Equal(new[] { "Show.S01E01.480p.x264-GRP" }, kept.Select(k => k.Title));
        Assert.Equal(2, f.Dropped["too small"]); // SD under 80 MB, HD under 200 MB
    }

    [Fact]
    public void Hard_rejections_are_counted_by_the_arr_reason() 
    {
        var f = new ReleaseFilter(new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration());
        f.Apply(new[] { R("Other.Show.S01E04.Bonanza.1080p.WEB-DL-GRP", 900 * MB, "Unknown Series") }, "episode", null);
        Assert.Equal(1, f.Dropped["Unknown Series"]);
    }
}
