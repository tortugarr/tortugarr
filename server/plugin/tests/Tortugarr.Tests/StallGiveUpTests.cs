using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-07: what happens to a download nothing could get going.</summary>
public class StallGiveUpTests
{
    private static readonly DateTimeOffset T0 = new(2026, 11, 7, 20, 0, 0, TimeSpan.Zero);
    private const long Gb = 1L << 30;

    private static JsonArray Dengus(long left = 2600000000L) => new()
    {
        new JsonObject
        {
            ["hash"] = "42e4fa93", ["name"] = "dengus", ["state"] = "stalledDL", ["progress"] = 0.617,
            ["amount_left"] = left, ["size"] = 6536892752L, ["completion_on"] = -1, ["force_start"] = false,
            ["category"] = "xxx",
        },
    };

    private static ReleaseDto R(string title, double gb, int? seeders, bool pack = false, string protocol = "torrent") => new()
    {
        Guid = title, Title = title, Size = (long)(gb * Gb), Seeders = seeders, SeasonPack = pack, Protocol = protocol,
    };

    [Fact]
    public void After_three_hours_without_data_the_download_is_given_up_once()
    {
        var tracks = new Dictionary<string, StallTrack>();
        for (var m = 0.0; m < 180; m += 0.5)
        {
            Assert.Empty(QbitWatchdog.DecideStalls(Dengus(), tracks, T0.AddMinutes(m)).GiveUp);
        }

        var plan = QbitWatchdog.DecideStalls(Dengus(), tracks, T0.AddMinutes(180));
        var dead = Assert.Single(plan.GiveUp);
        Assert.Equal("42e4fa93", dead.Hash);
        Assert.Equal("xxx", dead.Category);
        Assert.Empty(plan.Bounce);
        Assert.Empty(plan.Reannounce);

        var later = QbitWatchdog.DecideStalls(Dengus(), tracks, T0.AddMinutes(200));
        Assert.Empty(later.GiveUp);
        Assert.Empty(later.Bounce); // no more nudging once given up
    }

    [Fact]
    public void Any_new_data_starts_the_three_hours_again()
    {
        var tracks = new Dictionary<string, StallTrack>();
        QbitWatchdog.DecideStalls(Dengus(), tracks, T0);
        QbitWatchdog.DecideStalls(Dengus(2500000000L), tracks, T0.AddMinutes(170));
        Assert.Empty(QbitWatchdog.DecideStalls(Dengus(2500000000L), tracks, T0.AddMinutes(200)).GiveUp);
        Assert.Single(QbitWatchdog.DecideStalls(Dengus(2500000000L), tracks, T0.AddMinutes(350)).GiveUp);
    }

    [Fact]
    public void Seeders_win_over_a_closer_size()
    {
        var pick = TortugarrService.PickReplacement(new[] { R("close", 2.2, 2), R("popular", 2.6, 468) }, (long)(2.3 * Gb));
        Assert.Equal("popular", pick?.Title);
    }

    [Fact]
    public void Only_releases_within_two_gb_of_the_old_size_count()
    {
        var releases = new[] { R("huge", 9.0, 900), R("tiny", 0.3, 800), R("fits", 5.5, 12) };
        Assert.Equal("fits", TortugarrService.PickReplacement(releases, (long)(6.1 * Gb))?.Title);
    }

    [Fact]
    public void No_seeders_or_usenet_means_no_pick()
    {
        var releases = new[] { R("dead", 6.0, 0), R("unknown", 6.0, null), R("nzb", 6.0, 50, protocol: "usenet") };
        Assert.Null(TortugarrService.PickReplacement(releases, 6 * Gb));
    }

    [Fact]
    public void A_season_pack_is_replaced_by_a_pack_and_an_episode_by_an_episode()
    {
        var releases = new[] { R("pack", 20, 300, pack: true), R("episode", 20, 30) };
        Assert.Equal("pack", TortugarrService.PickReplacement(releases, 20 * Gb, wantPack: true)?.Title);
        Assert.Equal("episode", TortugarrService.PickReplacement(releases, 20 * Gb)?.Title);
    }

    [Fact]
    public void A_tie_in_seeders_goes_to_the_closer_size()
    {
        var pick = TortugarrService.PickReplacement(new[] { R("far", 7.9, 40), R("near", 6.2, 40) }, 6 * Gb);
        Assert.Equal("near", pick?.Title);
    }
}
