using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

public class QbitWatchdogTests
{
    private static readonly DateTimeOffset T0 = new(2026, 11, 5, 3, 0, 0, TimeSpan.Zero);

    // The real Widows Bay S01E04 entry from 2026-11-05 (trimmed).
    private static JsonObject Stuck(string hash = "05fd9dcd", string state = "stalledDL") => new()
    {
        ["hash"] = hash, ["name"] = "Widows Bay S01E04", ["state"] = state,
        ["progress"] = 1.0000046670791953, ["amount_left"] = -13446, ["size"] = 2881031034L, ["completion_on"] = -1,
    };

    private static JsonObject Healthy(string hash, string state = "downloading", double progress = 0.4) => new()
    {
        ["hash"] = hash, ["name"] = hash, ["state"] = state, ["progress"] = progress,
        ["amount_left"] = 1000, ["size"] = 5000L, ["completion_on"] = -1,
    };

    private static JsonArray List(params JsonObject[] t) => new(t.Select(x => x.DeepClone()).ToArray());

    [Fact]
    public void Only_a_downloading_torrent_at_100_percent_without_completion_is_stuck()
    {
        Assert.True(QbitWatchdog.FalselyComplete(Stuck()));
        Assert.False(QbitWatchdog.FalselyComplete(Healthy("a")));
        var done = Stuck(); done["completion_on"] = 1793847000; done["state"] = "stalledUP";
        Assert.False(QbitWatchdog.FalselyComplete(done));
        Assert.False(QbitWatchdog.FalselyComplete(Stuck(state: "stoppedDL"))); // the user stopped it
        Assert.False(QbitWatchdog.FalselyComplete(Stuck(state: "checkingDL")));
    }

    [Fact]
    public void A_stuck_torrent_is_rechecked_on_the_second_pass_only()
    {
        var s = new WatchdogState();
        Assert.Empty(QbitWatchdog.Decide(List(Stuck()), s, T0, true).Recheck);
        var plan = QbitWatchdog.Decide(List(Stuck()), s, T0 + QbitWatchdog.Every, true);
        Assert.Equal(new[] { "05fd9dcd" }, plan.Recheck);
        Assert.False(plan.Restart);
    }

    [Fact]
    public void A_recheck_that_never_starts_restarts_qbittorrent_once()
    {
        var s = new WatchdogState();
        QbitWatchdog.Decide(List(Stuck()), s, T0, true);
        QbitWatchdog.Decide(List(Stuck()), s, T0.AddMinutes(3), true);
        var hung = Stuck(state: "checkingResumeData");
        Assert.False(QbitWatchdog.Decide(List(hung), s, T0.AddMinutes(6), true).Restart);
        Assert.True(QbitWatchdog.Decide(List(hung), s, T0.AddMinutes(14), true).Restart);
        Assert.False(QbitWatchdog.Decide(List(hung), s, T0.AddMinutes(17), true).Restart); // not again within 30 min
    }

    [Fact]
    public void Without_the_keepalive_it_never_closes_qbittorrent()
    {
        var s = new WatchdogState();
        QbitWatchdog.Decide(List(Stuck()), s, T0, false);
        QbitWatchdog.Decide(List(Stuck()), s, T0.AddMinutes(3), false);
        Assert.False(QbitWatchdog.Decide(List(Stuck(state: "checkingResumeData")), s, T0.AddMinutes(20), false).Restart);
    }

    [Fact]
    public void A_restart_waits_while_another_torrent_is_being_hashed()
    {
        var s = new WatchdogState();
        QbitWatchdog.Decide(List(Stuck()), s, T0, true);
        QbitWatchdog.Decide(List(Stuck()), s, T0.AddMinutes(3), true);
        var hashing = Healthy("b", "checkingDL");
        Assert.False(QbitWatchdog.Decide(List(Stuck(state: "checkingResumeData"), hashing), s, T0.AddMinutes(15), true).Restart);
        Assert.True(QbitWatchdog.Decide(List(Stuck(state: "checkingResumeData")), s, T0.AddMinutes(18), true).Restart);
    }

    [Fact]
    public void A_torrent_that_recovers_or_leaves_is_forgotten()
    {
        var s = new WatchdogState();
        QbitWatchdog.Decide(List(Stuck()), s, T0, true);
        QbitWatchdog.Decide(List(Stuck()), s, T0.AddMinutes(3), true);
        QbitWatchdog.Decide(List(Healthy("05fd9dcd")), s, T0.AddMinutes(6), true);
        Assert.Empty(s.FirstSeen);
        QbitWatchdog.Decide(new JsonArray(), s, T0.AddMinutes(9), true);
        Assert.Empty(s.Rechecked);
    }

    // ---- stalled downloads (2026-11-07: "dengus" at 59.7 %, stalledDL, ten seeds announced)

    private static JsonObject Slow(string state = "stalledDL", long left = 2629112144L, bool forced = false) => new()
    {
        ["hash"] = "42e4fa93", ["name"] = "dengus", ["state"] = state, ["progress"] = 0.597,
        ["amount_left"] = left, ["size"] = 6536892752L, ["completion_on"] = -1, ["force_start"] = forced,
    };

    [Fact]
    public void A_download_without_new_data_gets_fresh_peers_after_5_minutes_and_a_restart_after_10()
    {
        var tracks = new Dictionary<string, StallTrack>();
        Assert.Empty(QbitWatchdog.DecideStalls(List(Slow()), tracks, T0).Reannounce);
        Assert.Empty(QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(3)).Reannounce);

        var at6 = QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(6));
        Assert.Equal(new[] { "42e4fa93" }, at6.Reannounce);
        Assert.Empty(at6.Bounce);
        Assert.Empty(QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(9)).Reannounce); // not every pass

        var at12 = QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(12));
        Assert.Equal(new[] { "42e4fa93" }, at12.Bounce);
        Assert.Empty(at12.Reannounce);
        Assert.Empty(QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(15)).Bounce); // not again within 1 h
        Assert.Equal(new[] { "42e4fa93" }, QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(24)).Reannounce);
        Assert.Equal(new[] { "42e4fa93" }, QbitWatchdog.DecideStalls(List(Slow()), tracks, T0.AddMinutes(72)).Bounce);
    }

    [Fact]
    public void New_data_starts_the_clock_again_even_when_qbittorrent_says_stalled_in_between()
    {
        var tracks = new Dictionary<string, StallTrack>();
        QbitWatchdog.DecideStalls(List(Slow()), tracks, T0);
        QbitWatchdog.DecideStalls(List(Slow("downloading", 2600000000L)), tracks, T0.AddMinutes(4));
        var plan = QbitWatchdog.DecideStalls(List(Slow("stalledDL", 2600000000L)), tracks, T0.AddMinutes(8));
        Assert.Empty(plan.Reannounce);
        Assert.Empty(plan.Bounce);
    }

    [Theory]
    [InlineData("stoppedDL")] // the user stopped it
    [InlineData("pausedDL")]
    [InlineData("queuedDL")]
    [InlineData("checkingDL")]
    [InlineData("metaDL")]
    [InlineData("forcedDL")]
    [InlineData("stalledUP")] // finished, seeding
    [InlineData("uploading")]
    public void Torrents_qbittorrent_does_not_run_on_its_own_are_never_touched(string state)
    {
        var tracks = new Dictionary<string, StallTrack>();
        for (var m = 0; m <= 180; m += 3)
        {
            var plan = QbitWatchdog.DecideStalls(List(Slow(state)), tracks, T0.AddMinutes(m));
            Assert.Empty(plan.Reannounce);
            Assert.Empty(plan.Bounce);
        }
    }

    [Fact]
    public void Force_started_and_falsely_complete_torrents_are_left_alone()
    {
        var tracks = new Dictionary<string, StallTrack>();
        for (var m = 0; m <= 60; m += 3)
        {
            var plan = QbitWatchdog.DecideStalls(List(Slow(forced: true), Stuck()), tracks, T0.AddMinutes(m));
            Assert.Empty(plan.Reannounce);
            Assert.Empty(plan.Bounce);
        }
    }

    [Fact]
    public void A_removed_torrent_is_forgotten()
    {
        var tracks = new Dictionary<string, StallTrack>();
        QbitWatchdog.DecideStalls(List(Slow()), tracks, T0);
        QbitWatchdog.DecideStalls(new JsonArray(), tracks, T0.AddMinutes(3));
        Assert.Empty(tracks);
    }
}
