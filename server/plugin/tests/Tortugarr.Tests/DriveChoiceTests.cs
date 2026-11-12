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

    // 2026-10-21: documentaries have folders of their own, and only they go there.
    [Theory]
    [InlineData("[\"Documentary\",\"Music\"]", true)]
    [InlineData("[\"documentary\"]", true)]
    [InlineData("[\"Thriller\",\"Drama\"]", false)]
    [InlineData("[]", false)]
    public void Documentaries_are_told_by_their_TMDB_genre(string genres, bool documentary) =>
        Assert.Equal(documentary, TortugarrService.IsDocumentary(new JsonObject { ["genres"] = JsonNode.Parse(genres) }));

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
        var best = TortugarrService.DownloadRootToFill(roots, p => free[p]);
        Assert.Equal("E:\\Downloads\\", best!.Value.Remote);
    }

    [Fact]
    public void Unreadable_download_root_is_ignored()
    {
        var roots = TortugarrService.ParseDownloadRoots("H:\\Downloads\\|/a\nE:\\Downloads\\|/b");
        var best = TortugarrService.DownloadRootToFill(roots, p => p == "/a" ? 5L << 30 : null);
        Assert.Equal("H:\\Downloads\\", best!.Value.Remote);
    }

    // 2026-11-08: fill the fullest drive first, down to 25 GB free; only then the next one.
    private const long Floor = 25L << 30;

    [Fact]
    public void The_fullest_drive_that_keeps_the_floor_is_filled_first()
    {
        var roots = Roots(("/data/library/3", 40), ("/data/library/7", 300), ("/data/library/9", 120));
        Assert.Equal("/data/library/3", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), floor: Floor));
    }

    [Fact]
    public void A_drive_under_the_floor_is_passed_over()
    {
        var roots = Roots(("/data/library/3", 11), ("/data/library/7", 300), ("/data/library/9", 120));
        Assert.Equal("/data/library/9", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), floor: Floor));
    }

    [Fact]
    public void The_download_size_counts_against_the_floor()
    {
        var roots = Roots(("/data/library/3", 40), ("/data/library/9", 120));
        // 40 GB minus a 20 GB release leaves 20 GB, under the floor.
        Assert.Equal("/data/library/9", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), need: 20L << 30, floor: Floor));
        Assert.Equal("/data/library/3", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), need: 10L << 30, floor: Floor));
    }

    [Fact]
    public void When_no_drive_keeps_the_floor_the_roomiest_wins()
    {
        var roots = Roots(("/data/library/3", 11), ("/data/library/9", 20));
        Assert.Equal("/data/library/9", TortugarrService.PickRoot(roots, TortugarrService.AllowedRoots(string.Empty), floor: Floor));
    }

    [Fact]
    public void Filling_keeps_the_type_list_and_the_main_folder_on_a_drive()
    {
        var roots = Roots(("/data/library/1", 30), ("/data/library/2", 52), ("/data/library/3", 52));
        var allowed = TortugarrService.AllowedRoots("/data/library/2,/data/library/3");
        var titles = TortugarrService.TitlesPerRoot(JsonNode.Parse(
            "[{\"rootFolderPath\":\"/data/library/3\"},{\"rootFolderPath\":\"/data/library/3\"}]")!.AsArray());
        Assert.Equal("/data/library/3", TortugarrService.PickRoot(roots, allowed, titles, floor: Floor));
    }

    [Fact]
    public void Download_folders_fill_the_fullest_drive_first()
    {
        var roots = TortugarrService.ParseDownloadRoots("H:\\Downloads\\|/h\nE:\\Downloads\\|/e\nI:\\Downloads\\|/i");
        var free = new Dictionary<string, long?> { ["/h"] = 111L << 30, ["/e"] = 11L << 30, ["/i"] = 644L << 30 };
        Assert.Equal("H:\\Downloads\\", TortugarrService.DownloadRootToFill(roots, p => free[p], 5L << 30, Floor)!.Value.Remote);
        // An 90 GB download would take H: under 25 GB: I: then.
        Assert.Equal("I:\\Downloads\\", TortugarrService.DownloadRootToFill(roots, p => free[p], 90L << 30, Floor)!.Value.Remote);
    }

    [Fact]
    public void Adult_downloads_fill_the_fullest_folder_first()
    {
        var folders = new List<(string, string)> { (@"E:\-=XxX=-", "/e"), (@"H:\-=XxX=-", "/h"), (@"I:\-=XxX=-", "/i") };
        var free = new Dictionary<string, long?> { ["/e"] = 11L << 30, ["/h"] = 111L << 30, ["/i"] = 644L << 30 };
        Assert.Equal(@"H:\-=XxX=-", TortugarrService.AdultSaveFolder(folders, p => free[p], 2L << 30, Floor));
    }

    [Theory]
    [InlineData("E:\\Downloads\\", "radarr", "E:\\Downloads\\radarr")]
    [InlineData("E:\\Downloads", "sonarr", "E:\\Downloads\\sonarr")]
    [InlineData("/volume1/downloads/", "radarr", "/volume1/downloads/radarr")]
    public void Category_path_keeps_the_client_separator(string root, string category, string expected) =>
        Assert.Equal(expected, TortugarrService.CategoryPath(root, category));

    [Fact]
    public void Movies_and_series_download_into_their_libraries_hidden_incoming_folders()
    {
        var c = new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration
        {
            DownloadRoots = "H:\\Downloads\\|/data/torrents-ext/1\nI:\\Downloads\\|/data/torrents-ext/5",
            IncomingRoots = "movies|H:\\-=MOVIES=-\\.incoming\\|/data/library/7/.incoming\n"
                + "movies|I:\\-=MOVIES=-\\.incoming\\|/data/library/14/.incoming\n"
                + "tv|I:\\-=Serier=-\\.incoming\\|/data/library/13/.incoming",
        };
        Assert.Equal(new[] { "H:\\-=MOVIES=-\\.incoming\\", "I:\\-=MOVIES=-\\.incoming\\" },
            TortugarrService.RootsFor("radarr", c).Select(r => r.Remote));
        Assert.Equal(new[] { "I:\\-=Serier=-\\.incoming\\" }, TortugarrService.RootsFor("sonarr", c).Select(r => r.Remote));
        // Other categories (adult) keep the download folders.
        Assert.Equal(2, TortugarrService.RootsFor("adult", c).Count);
    }

    [Fact]
    public void Without_incoming_folders_the_download_folders_are_used()
    {
        var c = new Jellyfin.Plugin.Tortugarr.Configuration.PluginConfiguration
        {
            DownloadRoots = "H:\\Downloads\\|/data/torrents-ext/1\nI:\\Downloads\\|/data/torrents-ext/5",
        };
        Assert.Equal("/data/torrents-ext/1", TortugarrService.RootsFor("radarr", c)[0].Local);
    }

    [Theory]
    [InlineData("/data/library/6/Planet Earth (2006)", "H:\\-=Dokumentarer=-\\.incoming\\")]
    [InlineData("/data/library/7/Rocky III (1982)", "H:\\-=MOVIES=-\\.incoming\\")]
    [InlineData("/data/library/70/Other (2000)", null)]
    public void A_grab_downloads_into_the_titles_own_library(string titlePath, string? expected)
    {
        const string roots = "movies|H:\\-=MOVIES=-\\.incoming\\|/data/library/7/.incoming\n"
            + "docs|H:\\-=Dokumentarer=-\\.incoming\\|/data/library/6/.incoming";
        Assert.Equal(expected, TortugarrService.IncomingForTitle(roots, titlePath)?.Remote);
    }
}
