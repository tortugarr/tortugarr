using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// Per-user download limits (user, 2026-10-25): the daughter may fetch at most 2.5 GB per movie and
/// 950 MB per episode, and a number of movies and episodes per week.
/// </summary>
public class UserLimitTests
{
    private const long Mb = 1024L * 1024;
    private static readonly Guid Her = Guid.Parse("8e1c0f6f4a5b4f3d9a0e2b7c6d5e4f3a");

    private static UserLimit Limit() => new()
    {
        UserId = Her.ToString("N"),
        Enabled = true,
        MaxMovieMb = 2560,
        MaxEpisodeMb = 950,
        MoviesPerWeek = 4,
        EpisodesPerWeek = 5,
    };

    [Fact]
    public void Movie_over_the_limit_is_refused_with_the_limit_in_the_reason()
    {
        Assert.Null(UserLimitService.SizeProblem(Limit(), "movie", 2560 * Mb, 0));
        Assert.Equal("Over your size limit (2.5 GB per movie)", UserLimitService.SizeProblem(Limit(), "movie", 2561 * Mb, 0));
    }

    [Fact]
    public void Episode_uses_the_episode_limit()
    {
        Assert.Null(UserLimitService.SizeProblem(Limit(), "episode", 900 * Mb, 0));
        Assert.Equal("Over your size limit (950 MB per episode)", UserLimitService.SizeProblem(Limit(), "episode", 951 * Mb, 0));
    }

    [Fact]
    public void Season_pack_is_judged_per_episode()
    {
        Assert.Null(UserLimitService.SizeProblem(Limit(), "season", 8 * 950 * Mb, 8));
        Assert.NotNull(UserLimitService.SizeProblem(Limit(), "season", (8 * 950 * Mb) + 1, 8));
    }

    [Fact]
    public void Season_pack_with_unknown_episode_count_is_refused()
    {
        Assert.NotNull(UserLimitService.SizeProblem(Limit(), "season", 100 * Mb, 0));
    }

    [Fact]
    public void Zero_means_no_limit()
    {
        var l = new UserLimit { Enabled = true };
        Assert.Null(UserLimitService.SizeProblem(l, "movie", 50_000 * Mb, 0));
        Assert.Null(UserLimitService.SizeProblem(l, "season", 50_000 * Mb, 0));
        Assert.Null(UserLimitService.QuotaProblem(l, (100, 100), "movie", 0));
    }

    [Fact]
    public void Weekly_movie_count_stops_the_fifth_movie()
    {
        Assert.Null(UserLimitService.QuotaProblem(Limit(), (3, 0), "movie", 0));
        Assert.Equal("You have used 4 of 4 movies this week", UserLimitService.QuotaProblem(Limit(), (4, 0), "movie", 0));
    }

    [Fact]
    public void Season_pack_counts_as_its_episodes()
    {
        Assert.Null(UserLimitService.QuotaProblem(Limit(), (0, 0), "season", 5));
        Assert.NotNull(UserLimitService.QuotaProblem(Limit(), (0, 1), "season", 5));
    }

    [Fact]
    public void Ledger_counts_only_the_last_seven_days_and_only_this_user()
    {
        var now = DateTimeOffset.Parse("2026-10-25T12:00:00Z");
        var grabs = new[]
        {
            new UserGrab { UserId = Her.ToString("N"), Type = "movie", Count = 1, At = now.AddDays(-1) },
            new UserGrab { UserId = Her.ToString("N"), Type = "season", Count = 8, At = now.AddDays(-6.9) },
            new UserGrab { UserId = Her.ToString("N"), Type = "movie", Count = 1, At = now.AddDays(-7.1) },
            new UserGrab { UserId = Guid.NewGuid().ToString("N"), Type = "movie", Count = 1, At = now },
        };
        Assert.Equal((1, 8), UserLimitService.Count(grabs, Her, now));
    }

    [Fact]
    public void Recorded_grabs_survive_in_the_ledger_file()
    {
        var dir = Path.Combine(Path.GetTempPath(), "tortugarr-limits-" + Guid.NewGuid().ToString("N"));
        try
        {
            var path = Path.Combine(dir, "user-grabs.json");
            var now = DateTimeOffset.UtcNow;
            new UserLimitService(NullLogger<UserLimitService>.Instance, path).Record(Her, "episode", 1, 900 * Mb, now);
            new UserLimitService(NullLogger<UserLimitService>.Instance, path).Record(Her, "movie", 1, 2000 * Mb, now);
            Assert.Equal((1, 1), new UserLimitService(NullLogger<UserLimitService>.Instance, path).Used(Her, now));
        }
        finally
        {
            if (Directory.Exists(dir))
            {
                Directory.Delete(dir, true);
            }
        }
    }

    [Fact]
    public void Reserve_takes_the_place_before_the_grab_and_stops_the_third_movie()
    {
        var dir = Path.Combine(Path.GetTempPath(), "tortugarr-limits-" + Guid.NewGuid().ToString("N"));
        try
        {
            var svc = new UserLimitService(NullLogger<UserLimitService>.Instance, Path.Combine(dir, "user-grabs.json"));
            var two = new UserLimit { Enabled = true, MoviesPerWeek = 2, EpisodesPerWeek = 1 };
            var now = DateTimeOffset.UtcNow;
            svc.Reserve(Her, two, "movie", 1, 1, now);   // counted even if Radarr answers late
            var second = svc.Reserve(Her, two, "movie", 1, 1, now);
            var e = Assert.Throws<LimitException>(() => svc.Reserve(Her, two, "movie", 1, 1, now));
            Assert.Equal("quota_exceeded", e.Code);

            // A refused grab gives its place back.
            svc.Release(second);
            svc.Reserve(Her, two, "movie", 1, 1, now);
            Assert.Equal((2, 0), svc.Used(Her, now));

            svc.Reserve(Her, two, "episode", 1, 1, now);
            Assert.Throws<LimitException>(() => svc.Reserve(Her, two, "episode", 1, 1, now));
        }
        finally
        {
            if (Directory.Exists(dir))
            {
                Directory.Delete(dir, true);
            }
        }
    }

    [Fact]
    public void Only_a_grab_we_stopped_waiting_for_keeps_its_place()
    {
        Assert.True(UserLimitService.MayHaveGrabbed(new TaskCanceledException()));
        Assert.True(UserLimitService.MayHaveGrabbed(new UpstreamException("Radarr", "no answer within 60 s")));
        Assert.False(UserLimitService.MayHaveGrabbed(new UpstreamException("Radarr", "HTTP 400 Unable to find matching movie")));
        Assert.False(UserLimitService.MayHaveGrabbed(new SearchExpiredException()));
    }

    [Fact]
    public void Disabled_or_unknown_user_has_no_limit_entry_found_only_by_id()
    {
        var all = new[] { Limit() };
        Assert.NotNull(UserLimitService.Find(all, Her));
        Assert.Null(UserLimitService.Find(all, Guid.NewGuid()));
    }

    [Fact]
    public void Sizes_read_like_people_write_them()
    {
        Assert.Equal("2.5 GB", UserLimitService.Show(2560));
        Assert.Equal("950 MB", UserLimitService.Show(950));
    }
}

/// <summary>New titles get the wide 720p-2160p profile when the server has one (2026-10-25).</summary>
public class QualityProfileTests
{
    private static JsonArray Profiles(params string[] names) =>
        new(names.Select((n, i) => (JsonNode)new JsonObject { ["id"] = i + 1, ["name"] = n }).ToArray());

    [Fact]
    public void Wide_profile_wins_over_HD_1080p()
    {
        Assert.Equal(3, TortugarrService.PickDefaultProfile(Profiles("Any", "HD-1080p", "720p-2160p")));
        Assert.Equal(2, TortugarrService.PickDefaultProfile(Profiles("Any", "HD-1080p")));
        Assert.Equal(1, TortugarrService.PickDefaultProfile(Profiles("Any")));
    }

    [Fact]
    public void A_profile_allows_a_quality_inside_an_allowed_group()
    {
        var profile = JsonNode.Parse("""
            {"items":[
              {"name":"WEB 2160p","allowed":true,"items":[{"quality":{"name":"WEBDL-2160p"}},{"quality":{"name":"WEBRip-2160p"}}]},
              {"quality":{"name":"Bluray-1080p"},"allowed":true,"items":[]},
              {"quality":{"name":"Remux-2160p"},"allowed":false,"items":[]}
            ]}
            """);
        Assert.True(TortugarrService.ProfileAllows(profile, "WEBDL-2160p"));
        Assert.True(TortugarrService.ProfileAllows(profile, "Bluray-1080p"));
        Assert.False(TortugarrService.ProfileAllows(profile, "Remux-2160p"));
        Assert.False(TortugarrService.ProfileAllows(profile, "HDTV-720p"));
    }
}
