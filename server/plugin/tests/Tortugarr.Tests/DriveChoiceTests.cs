using System.Text.Json.Nodes;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>
/// Several drives: new movies go to the roomiest folder of the right type, and downloads to the
/// roomiest download folder (2026-10-20: H: had 5 GB left while E: had 53 GB, and a series folder
/// not mounted into Radarr reported 866 GB and was picked for movies).
/// </summary>
public class DriveChoiceTests
{
    private static JsonArray Roots(params (string Path, long FreeGb)[] roots) =>
        new(roots.Select(r => (JsonNode)new JsonObject
        {
            ["path"] = r.Path, ["accessible"] = true, ["freeSpace"] = r.FreeGb << 30,
        }).ToArray());

    [Fact]
    public void Root_of_another_type_is_skipped()
    {
        var roots = Roots(("/data/library/1", 866), ("/data/library/3", 52), ("/data/library/7", 5));
        var allowed = TortugarrService.AllowedRoots("/data/media/movies,/data/library/3,/data/library/7/");
        Assert.Equal("/data/library/3", TortugarrService.PickRoot(roots, allowed));
    }

    [Fact]
    public void On_one_drive_the_folder_with_most_titles_wins()
    {
        var roots = Roots(("/data/library/2", 52), ("/data/library/3", 52));
        var titles = TortugarrService.TitlesPerRoot(JsonNode.Parse(
            "[{\"rootFolderPath\":\"/data/library/2/\"},{\"rootFolderPath\":\"/data/library/3\"},{\"rootFolderPath\":\"/data/library/3\"}]")!.AsArray());
        Assert.Equal("/data/library/3", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), titles));
    }

    [Fact]
    public void Without_a_list_every_root_counts()
    {
        var roots = Roots(("/data/library/1", 866), ("/data/library/3", 52));
        Assert.Equal("/data/library/1", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty)));
    }

    [Fact]
    public void Download_roots_parse_and_the_roomiest_wins()
    {
        var roots = TortugarrService.ParseDownloadRoots("H:\\Downloads\\|/data/torrents-ext/1\nE:\\Downloads\\|/data/torrents-ext/2\n");
        Assert.Equal(2, roots.Count);
        var free = new Dictionary<string, long?> { ["/data/torrents-ext/1"] = 5L << 30, ["/data/torrents-ext/2"] = 53L << 30 };
        var best = TortugarrService.RoomiestDownloadRoot(roots, p => free[p]);
        Assert.Equal("E:\\Downloads\\", best!.Value.Remote);
    }

    [Fact]
    public void Unreadable_download_root_is_ignored()
    {
        var roots = TortugarrService.ParseDownloadRoots("H:\\Downloads\\|/a\nE:\\Downloads\\|/b");
        var best = TortugarrService.RoomiestDownloadRoot(roots, p => p == "/a" ? 5L << 30 : null);
        Assert.Equal("H:\\Downloads\\", best!.Value.Remote);
    }

    [Theory]
    [InlineData("E:\\Downloads\\", "radarr", "E:\\Downloads\\radarr")]
    [InlineData("E:\\Downloads", "sonarr", "E:\\Downloads\\sonarr")]
    [InlineData("/volume1/downloads/", "radarr", "/volume1/downloads/radarr")]
    public void Category_path_keeps_the_client_separator(string root, string category, string expected) =>
        Assert.Equal(expected, TortugarrService.CategoryPath(root, category));
}
