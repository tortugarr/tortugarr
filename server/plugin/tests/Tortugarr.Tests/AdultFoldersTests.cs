using Jellyfin.Plugin.Tortugarr.Configuration;
using Jellyfin.Plugin.Tortugarr.Services;
using Xunit;

namespace Tortugarr.Tests;

/// <summary>2026-11-07: E: was full and adult downloads still went there; H:\-=XxX=- sat empty.</summary>
public class AdultFoldersTests
{
    private static PluginConfiguration Cfg(string more = "") => new()
    {
        AdultSavePath = "/data/library/5", AdultDownloadPath = @"E:\-=XxX=-", AdultFolders = more,
    };

    [Fact]
    public void Without_more_folders_it_is_the_save_path_as_before()
    {
        Assert.Equal(new[] { (@"E:\-=XxX=-", "/data/library/5") }, AdultLibraryService.Folders(Cfg()));
        var plain = new PluginConfiguration { AdultSavePath = "/data/media/adult" };
        Assert.Equal(new[] { ("/data/media/adult", "/data/media/adult") }, AdultLibraryService.Folders(plain));
    }

    [Fact]
    public void More_folders_follow_the_save_path_once_each()
    {
        var c = Cfg("E:\\-=XxX=-|/data/library/5\nH:\\-=XxX=-|/data/library/10\n");
        Assert.Equal(new[] { (@"E:\-=XxX=-", "/data/library/5"), (@"H:\-=XxX=-", "/data/library/10") }, AdultLibraryService.Folders(c));
    }

    [Fact]
    public void A_download_goes_to_the_folder_with_the_most_free_space()
    {
        var folders = AdultLibraryService.Folders(Cfg(@"H:\-=XxX=-|/data/library/10"));
        var free = new Dictionary<string, long?> { ["/data/library/5"] = 11L << 30, ["/data/library/10"] = 118L << 30 };
        Assert.Equal(@"H:\-=XxX=-", TortugarrService.AdultSaveFolder(folders, p => free[p]));
        free["/data/library/5"] = 500L << 30;
        Assert.Equal(@"E:\-=XxX=-", TortugarrService.AdultSaveFolder(folders, p => free[p]));
    }

    [Fact]
    public void A_folder_jellyfin_cannot_see_is_skipped_and_with_none_the_save_path_is_used()
    {
        var folders = AdultLibraryService.Folders(Cfg(@"H:\-=XxX=-|/data/library/10"));
        Assert.Equal(@"E:\-=XxX=-", TortugarrService.AdultSaveFolder(folders, p => p == "/data/library/5" ? 1L : null));
        Assert.Equal(@"E:\-=XxX=-", TortugarrService.AdultSaveFolder(folders, _ => null));
    }

    [Fact]
    public void A_file_belongs_to_the_adult_folder_it_is_in()
    {
        var c = Cfg(@"H:\-=XxX=-|/data/library/10");
        Assert.Equal("/data/library/10", AdultLibraryService.FolderOf(c, "/data/library/10/HMN-594/a.mp4"));
        Assert.Equal("/data/library/5", AdultLibraryService.FolderOf(c, "/data/library/5/a.mp4"));
        Assert.Null(AdultLibraryService.FolderOf(c, "/data/library/1/a.mp4"));
        Assert.Null(AdultLibraryService.FolderOf(c, "/data/library/50/a.mp4"));
        Assert.Null(AdultLibraryService.FolderOf(c, null));
    }

    [Fact]
    public void A_download_on_the_second_folder_is_found_for_delete()
    {
        Assert.True(LibraryDeleteService.OwnsFile(@"H:\-=XxX=-\HMN-594\hhd800.com@HMN-594.mp4",
            "/data/library/10/HMN-594/hhd800.com@HMN-594.mp4", "/data/library/10", @"H:\-=XxX=-"));
        // Another download's file of the same name in another folder is not it.
        Assert.False(LibraryDeleteService.OwnsFile(@"H:\-=XxX=-\Other\hhd800.com@HMN-594.mp4",
            "/data/library/10/HMN-594/hhd800.com@HMN-594.mp4", "/data/library/10", @"H:\-=XxX=-"));
    }
}
