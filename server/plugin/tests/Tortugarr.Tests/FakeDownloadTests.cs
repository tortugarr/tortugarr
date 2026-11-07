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
}
