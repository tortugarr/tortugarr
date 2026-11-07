using System.Text.Json;
using Jellyfin.Plugin.Tortugarr.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-07: Seerr › Requests showed the movies downloaded in the app, never the series.</summary>
public class SeriesRequestLogTests
{
    private static readonly DateTimeOffset T0 = new(2026, 11, 7, 12, 0, 0, TimeSpan.Zero);
    private static readonly Guid Me = Guid.Parse("11111111111111111111111111111111");
    private static readonly Guid Kid = Guid.Parse("22222222222222222222222222222222");

    private static SeriesGrab G(Guid user, int tvdb, int minutes, int? season = 1, int? episode = 1, string? id = null) => new()
    {
        UserId = user.ToString("N"), TvdbId = tvdb, TmdbId = tvdb + 1000, Title = "Show " + tvdb,
        Season = season, Episode = episode, DownloadId = id, At = T0.AddMinutes(minutes),
    };

    private static List<JsonElement> Rows(IEnumerable<SeriesGrab> grabs, Guid? only, params string[] queued) =>
        SeriesRequestLog.Rows(grabs, only, new HashSet<string>(queued, StringComparer.OrdinalIgnoreCase), id => id[..4])
            .Select(r => JsonSerializer.SerializeToElement(r)).ToList();

    [Fact]
    public void One_row_per_series_and_user_newest_first()
    {
        var rows = Rows(new[] { G(Me, 10, 0), G(Me, 10, 5, 1, 2), G(Me, 20, 3, 2, null), G(Kid, 10, 1) }, null);
        Assert.Equal(3, rows.Count);
        Assert.Equal(10, rows[0].GetProperty("tvdbId").GetInt32());
        Assert.Equal(2, rows[0].GetProperty("downloads").GetInt32());
        Assert.Equal(20, rows[1].GetProperty("tvdbId").GetInt32());
        Assert.Equal(1010, rows[0].GetProperty("tmdbId").GetInt32());
        Assert.Equal("Show 10", rows[0].GetProperty("title").GetString());
        Assert.Equal("1111", rows[0].GetProperty("userName").GetString());
    }

    [Fact]
    public void A_user_sees_only_their_own()
    {
        var rows = Rows(new[] { G(Me, 10, 0), G(Kid, 20, 1) }, Kid);
        Assert.Single(rows);
        Assert.Equal(20, rows[0].GetProperty("tvdbId").GetInt32());
    }

    [Fact]
    public void Downloading_while_a_download_is_in_sonarrs_queue()
    {
        var grabs = new[] { G(Me, 10, 0, id: "AAA"), G(Me, 10, 1, id: "BBB") };
        Assert.True(Rows(grabs, null, "bbb")[0].GetProperty("downloading").GetBoolean());
        Assert.False(Rows(grabs, null, "CCC")[0].GetProperty("downloading").GetBoolean());
    }

    [Fact]
    public void The_list_survives_a_restart_and_forgets_after_180_days()
    {
        var dir = Directory.CreateTempSubdirectory();
        try
        {
            var path = Path.Combine(dir.FullName, "series-grabs.json");
            var log = new SeriesRequestLog(NullLogger<SeriesRequestLog>.Instance, path);
            log.Add(G(Me, 10, 0));
            Assert.Single(new SeriesRequestLog(NullLogger<SeriesRequestLog>.Instance, path).All());
            log.Add(G(Me, 20, (int)SeriesRequestLog.Keep.TotalMinutes + 1));
            Assert.Equal(new[] { 20 }, log.All().Select(g => g.TvdbId));
        }
        finally
        {
            dir.Delete(true);
        }
    }

    private static System.Text.Json.Nodes.JsonObject H(string id, int season, int episode, string date = "2026-11-06T11:01:33Z", int tvdb = 72449) => new()
    {
        ["date"] = date, ["downloadId"] = id, ["eventType"] = "grabbed",
        ["series"] = new System.Text.Json.Nodes.JsonObject { ["title"] = "Stargate SG-1", ["tvdbId"] = tvdb, ["tmdbId"] = 4629 },
        ["episode"] = new System.Text.Json.Nodes.JsonObject { ["seasonNumber"] = season, ["episodeNumber"] = episode },
    };

    [Fact]
    public void Sonarr_history_becomes_grabs_with_a_season_pack_as_one()
    {
        var history = new System.Text.Json.Nodes.JsonArray(
            H("PACK", 6, 21), H("PACK", 6, 22), H("ONE", 1, 3, "2026-11-01T10:00:00Z"),
            H("OLD", 1, 1, "2026-06-01T10:00:00Z"), H("NOTV", 1, 1, tvdb: 0));
        var grabs = SeriesRequestLog.FromSonarrHistory(history, Me.ToString("N"), T0.AddDays(-90));
        Assert.Equal(2, grabs.Count);
        var pack = grabs.Single(g => g.DownloadId == "PACK");
        Assert.Equal(6, pack.Season);
        Assert.Null(pack.Episode);
        Assert.Equal(4629, pack.TmdbId);
        Assert.Equal("Stargate SG-1", pack.Title);
        Assert.Equal(3, grabs.Single(g => g.DownloadId == "ONE").Episode);
    }

    [Fact]
    public void Backfill_runs_once_and_skips_downloads_already_listed()
    {
        var dir = Directory.CreateTempSubdirectory();
        try
        {
            var log = new SeriesRequestLog(NullLogger<SeriesRequestLog>.Instance, Path.Combine(dir.FullName, "series-grabs.json"));
            log.Add(G(Me, 10, 0, id: "AAA"));
            Assert.False(log.Backfilled);
            Assert.Equal(1, log.Backfill(new[] { G(Me, 10, -60, id: "AAA"), G(Me, 20, -30, id: "BBB") }, T0));
            Assert.True(log.Backfilled);
            Assert.Equal(0, log.Backfill(new[] { G(Me, 30, -10, id: "CCC") }, T0));
            Assert.Equal(new[] { 20, 10 }, log.All().Select(g => g.TvdbId));
        }
        finally
        {
            dir.Delete(true);
        }
    }
}
