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
}
