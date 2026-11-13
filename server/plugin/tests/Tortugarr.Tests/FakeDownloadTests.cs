using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-07: finished Radarr/Sonarr downloads with no video must not stay in qBittorrent.</summary>
public class FakeDownloadTests
{
    private static readonly DateTimeOffset T0 = new(2026, 11, 7, 21, 0, 0, TimeSpan.Zero);

    private static JsonObject Rec(int id, string downloadId, string title, string message,
        string tracked = "importPending", string status = "completed", long sizeleft = 0) => new()
    {
        ["id"] = id, ["downloadId"] = downloadId, ["title"] = title, ["trackedDownloadState"] = tracked,
        ["status"] = status, ["sizeleft"] = sizeleft,
        ["statusMessages"] = new JsonArray { new JsonObject { ["title"] = title, ["messages"] = new JsonArray { message } } },
    };

    [Theory]
    [InlineData("No files found are eligible for import in /data/library/9/.incoming/Nocturne S01E03 Eyes on the Inside 1080p WEB H264-MeGusta.exe")]
    [InlineData("Invalid video file, unsupported extension: '.zip'")]
    [InlineData("Caution: Found potentially dangerous file with extension: .exe")]
    public void A_finished_download_without_video_is_fake(string message)
    {
        var fakes = TortugarrService.FindFakes("Sonarr", new JsonArray { Rec(7, "ABC", "Nocturne S01E03", message) });
        var f = Assert.Single(fakes);
        Assert.Equal(("Sonarr", 7, "ABC"), (f.Arr, f.QueueId, f.DownloadId));
    }

    [Theory]
    [InlineData("Not an upgrade for existing episode file(s)")]
    [InlineData("Unable to determine if file is a sample")]
    [InlineData("One or more episodes expected in this release were not imported or missing from the release")]
    public void A_real_file_waiting_for_a_decision_is_left_alone(string message)
    {
        Assert.Empty(TortugarrService.FindFakes("Sonarr", new JsonArray { Rec(7, "ABC", "Show S01E01", message) }));
    }

    [Fact]
    public void Still_downloading_or_not_import_pending_is_left_alone()
    {
        const string exe = "No files found are eligible for import in /x.exe";
        var records = new JsonArray
        {
            Rec(1, "A", "a", exe, status: "downloading", sizeleft: 100),
            Rec(2, "B", "b", exe, tracked: "downloading"),
        };
        Assert.Empty(TortugarrService.FindFakes("Radarr", records));
    }

    [Fact]
    public void A_season_pack_is_one_download()
    {
        const string zip = "Invalid video file, unsupported extension: '.zip'";
        var records = new JsonArray { Rec(1, "PACK", "S01E01", zip), Rec(2, "PACK", "S01E02", zip) };
        Assert.Single(TortugarrService.FindFakes("Sonarr", records));
    }

    [Fact]
    public void A_fake_goes_only_on_the_second_pass_and_gone_ones_are_forgotten()
    {
        var seen = new Dictionary<string, DateTimeOffset>();
        var fake = new FakeDownload("Sonarr", 7, "ABC", "Nocturne", "exe");
        Assert.Empty(QbitWatchdog.DecideFakes(new() { fake }, seen, T0));
        Assert.Empty(QbitWatchdog.DecideFakes(new() { fake }, seen, T0.AddMinutes(1)));
        Assert.Single(QbitWatchdog.DecideFakes(new() { fake }, seen, T0.AddMinutes(3)));
        Assert.Empty(seen);

        Assert.Empty(QbitWatchdog.DecideFakes(new() { fake }, seen, T0.AddMinutes(4)));
        Assert.Empty(QbitWatchdog.DecideFakes(new(), seen, T0.AddMinutes(7)));
        Assert.Empty(seen);
    }

    // 2026-11-13: drive I: was not mounted after a Windows restart. Radarr could not reach the
    // finished films and Tortugarr deleted two complete 4K downloads as "fake".
    [Theory]
    [InlineData("Import failed, path does not exist or is not accessible by Radarr: /data/library/14/.incoming/radarr/Pacific Rim (2013) 4K.mkv")]
    [InlineData("No files found are eligible for import in /data/library/14/.incoming/radarr/x; path does not exist or is not accessible by Radarr")]
    [InlineData("Access to the path '/data/library/7/.incoming/x' is denied.")]
    public void A_download_radarr_cannot_reach_is_never_fake(string message)
    {
        Assert.Empty(TortugarrService.FindFakes("Radarr", new JsonArray { Rec(9, "PR", "Pacific Rim", message) }));
    }

    [Fact]
    public void A_torrent_with_a_real_video_file_holds_video()
    {
        Assert.True(TortugarrService.HoldsVideo(new[] { ("Pacific Rim (2013) 4K.mkv", 25_969_762_472L), ("info.nfo", 2_000L) }));
        Assert.True(TortugarrService.HoldsVideo(new[] { ("BDMV/STREAM/00001.M2TS", 40_000_000_000L) }));
    }

    [Fact]
    public void A_torrent_with_only_an_exe_zip_or_sample_holds_no_video()
    {
        Assert.False(TortugarrService.HoldsVideo(new[] { ("Nocturne S01E03.exe", 2_000_000L) }));
        Assert.False(TortugarrService.HoldsVideo(new[] { ("Nocturne.S01E04.zip", 781_681_950L) }));
        Assert.False(TortugarrService.HoldsVideo(new[] { ("Sample/sample.mkv", 40_000_000L) }));
        Assert.False(TortugarrService.HoldsVideo(Array.Empty<(string, long)>()));
    }
}
