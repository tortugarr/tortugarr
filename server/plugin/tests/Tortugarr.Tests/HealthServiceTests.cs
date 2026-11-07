using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-08: the admin dashboard's server health.</summary>
public class HealthServiceTests
{
    private const long Gb = 1L << 30;

    private static readonly string[] MountInfo =
    {
        @"2679 2616 0:79 /-=MUSIC=- /data/library/8 ro,noatime - 9p H:\134 rw,aname=drvfs;path=H:\;uid=1000",
        @"2680 2616 0:76 /-=Serier=- /data/library/4 ro,noatime - 9p E:\134 rw,aname=drvfs;path=E:\;uid=1000",
        @"2681 2616 0:76 /-=MOVIES=- /data/library/3 ro,noatime - 9p E:\134 rw,aname=drvfs;path=E:\;uid=1000",
        @"2600 2500 0:30 / / rw,relatime - overlay overlay rw,lowerdir=/x",
    };

    [Fact]
    public void Mount_info_gives_the_windows_drive_and_device()
    {
        var m = HealthService.ParseMountInfo(MountInfo);
        Assert.Equal(new MountPoint("0:76", "E:"), m["/data/library/3"]);
        Assert.Equal(new MountPoint("0:79", "H:"), m["/data/library/8"]);
        Assert.Null(m["/"].Drive);
        Assert.Equal("E:", HealthService.MountOf(m, "/data/library/4/Show")?.Drive);
        Assert.Null(HealthService.MountOf(m, "/config")?.Drive);
    }

    [Fact]
    public void Libraries_on_one_disk_are_one_entry_with_a_level()
    {
        var m = HealthService.ParseMountInfo(MountInfo);
        var disks = HealthService.BuildDisks(new[]
        {
            new LibraryFolder("Movies", "/data/library/3", 11 * Gb, 2000 * Gb, m["/data/library/3"]),
            new LibraryFolder("Series", "/data/library/4", 11 * Gb, 2000 * Gb, m["/data/library/4"]),
            new LibraryFolder("Music", "/data/library/8", 111 * Gb, 2000 * Gb, m["/data/library/8"]),
        });
        Assert.Equal(2, disks.Count);
        Assert.Equal(("E:", "warning"), (disks[0].Drive, disks[0].Level));
        Assert.Equal(new[] { "Movies", "Series" }, disks[0].Libraries);
        Assert.Equal(("H:", "ok"), (disks[1].Drive, disks[1].Level));
    }

    [Theory]
    [InlineData(1L, "error")]
    [InlineData(20L, "warning")]
    [InlineData(80L, "warning")] // under 5 % of 2 TB
    [InlineData(300L, "ok")]
    public void Disk_levels(long freeGb, string level)
    {
        var d = Assert.Single(HealthService.BuildDisks(new[] { new LibraryFolder("Movies", "/m", freeGb * Gb, 2000 * Gb, null) }));
        Assert.Equal(level, d.Level);
        Assert.Null(d.Drive);
    }

    [Fact]
    public void Arr_health_keeps_real_warnings_and_marks_updates_as_info()
    {
        var items = JsonNode.Parse("""
            [
              {"source":"DownloadClientRootFolderCheck","type":"warning","message":"places downloads in the root folder"},
              {"source":"UpdateCheck","type":"warning","message":"New update is available: v2.7.0"},
              {"source":"IndexerStatusCheck","type":"error","message":"Indexers unavailable due to failures: 1337x"},
              {"source":"Something","type":"notice","message":"fyi"}
            ]
            """) as JsonArray;
        var w = HealthService.FromArrHealth("Prowlarr", items);
        Assert.Equal(2, w.Count);
        Assert.Equal(new HealthWarning("Prowlarr", "info", "New update is available: v2.7.0"), w[0]);
        Assert.Equal("error", w[1].Level);
    }

    [Fact]
    public void Overall_is_the_worst_and_info_does_not_count()
    {
        var up = new[] { new ServiceState("radarr", "Radarr", true, "6", null) };
        var down = new[] { new ServiceState("radarr", "Radarr", false, "", "no answer") };
        var okDisk = new[] { new DiskState("H:", new() { "Music" }, 300 * Gb, 2000 * Gb, "ok") };
        var info = new[] { new HealthWarning("Prowlarr", "info", "update") };
        Assert.Equal("ok", HealthService.Overall(up, okDisk, info));
        Assert.Equal("warning", HealthService.Overall(up, new[] { okDisk[0] with { Level = "warning" } }, info));
        Assert.Equal("error", HealthService.Overall(down, okDisk, info));
    }
}
