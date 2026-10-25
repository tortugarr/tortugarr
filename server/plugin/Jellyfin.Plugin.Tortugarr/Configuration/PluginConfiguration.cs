using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.Tortugarr.Configuration;

/// <summary>
/// Server-side settings. Written by the Tortugarr installer and changed on the settings page;
/// keys and passwords are never returned by any route (the page only learns whether one is set).
/// Addresses are container names on the stack's network (http://radarr:7878 ...).
/// </summary>
public class PluginConfiguration : BasePluginConfiguration
{
    public string SonarrUrl { get; set; } = string.Empty;

    public string SonarrApiKey { get; set; } = string.Empty;

    public string RadarrUrl { get; set; } = string.Empty;

    public string RadarrApiKey { get; set; } = string.Empty;

    public string ProwlarrUrl { get; set; } = string.Empty;

    public string ProwlarrApiKey { get; set; } = string.Empty;

    public string BazarrUrl { get; set; } = string.Empty;

    public string BazarrApiKey { get; set; } = string.Empty;

    /// <summary>Seerr, only to clear a title after a delete (spec 3.10, 3.11). Never returned by a route.</summary>
    public string SeerrUrl { get; set; } = string.Empty;

    public string SeerrApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Shared key Radarr/Sonarr send to the refresh hook (spec 3.12) in the X-Tortugarr-Hook-Key
    /// header. Written by the installer; it can only trigger a refresh. Never returned by a route.
    /// </summary>
    public string HookKey { get; set; } = string.Empty;

    /// <summary>Spec 3.15: free space kept on top of a release before a download (the app's 10 GB buffer).</summary>
    public long SpaceBufferBytes { get; set; } = 10L * 1024 * 1024 * 1024;

    /// <summary>qbittorrent, transmission, deluge or none. Only qBittorrent can list torrent files (video check, free space).</summary>
    public string DownloadClientType { get; set; } = "none";

    public string DownloadClientUrl { get; set; } = string.Empty;

    public string DownloadClientUsername { get; set; } = string.Empty;

    public string DownloadClientPassword { get; set; } = string.Empty;

    /// <summary>Folders the client downloads to, one per line as "its path|our path"
    /// (H:\Downloads\|/data/torrents-ext/1). With more than one, each grab goes to the one with
    /// the most free space. Written by the installer.</summary>
    public string DownloadRoots { get; set; } = string.Empty;

    /// <summary>Radarr root folders a new movie may go to (comma-separated); empty = any.</summary>
    public string MovieRoots { get; set; } = string.Empty;

    /// <summary>Radarr root folders for documentaries (comma-separated), the only folders a movie
    /// TMDB lists as a documentary goes to, and never another movie. Empty: documentaries are
    /// movies like any other.</summary>
    public string DocumentaryRoots { get; set; } = string.Empty;

    /// <summary>Sonarr root folders a new series may go to (comma-separated); empty = any.</summary>
    public string TvRoots { get; set; } = string.Empty;

    public string MovieCategory { get; set; } = "radarr";

    public string TvCategory { get; set; } = "sonarr";

    // ---- Filters (spec section 4); the defaults are what the app does today.

    public string JunkRegex { get; set; } =
        @"\b(HD-?CAM|CAM-?RIP|HQ-?CAM|CAM|HD-?TS|TS-?RIP|TELESYNC|PDVD|HD-?TC|TELECINE|DVD-?SCR|SCREENER|WORKPRINT|TS|TC|exe|scr|lnk|msi)\b";

    public string QualityRegex { get; set; } =
        @"\b(720p|1080p|2160p|BluRay|Blu-Ray|BDRip|BRRip|BDRemux|REMUX|DVDRip|DVD9|DVD5|DVD|WEB-?DL|WEBRip|WEB|HDRip)\b";

    public long MinEpisodeBytes { get; set; } = 200L * 1024 * 1024;

    public long MinMovieBytes { get; set; } = 700L * 1024 * 1024;

    /// <summary>Spec 4.1.5: minimum sizes for SD releases kept by allowSd (the HD minimums stop real SD files).</summary>
    public long MinSdEpisodeBytes { get; set; } = 80L * 1024 * 1024;

    public long MinSdMovieBytes { get; set; } = 350L * 1024 * 1024;

    public string BannedExtensions { get; set; } =
        ".exe .msi .apk .app .dmg .pkg .bat .cmd .ps1 .sh .scr .com .jar .py .rb .pl .php .zip .rar .7z .tar .gz .bz2 .xz .iso .img .vhd .vhdx .pdf .doc .docx .txt .rtf";

    public int EarlyReleaseDays { get; set; } = 2;

    public string HardRejectionRegex { get; set; } =
        @"blocklist|not enough seeders|must not contain|terms which are not allowed|unknown series|unable to parse|not requested|wasn.t requested|does not match|doesn.t match|wrong (series|episode|season)";

    public string VideoExtensions { get; set; } = ".mkv .mp4 .m4v .avi .mov .wmv .ts .m2ts .webm .mpg .mpeg .vob";

    public long MinVideoBytes { get; set; } = 50L * 1024 * 1024;

    public int SearchTimeoutSeconds { get; set; } = 150;

    // ---- Adult library (spec 3.9 / 4.7). Off until an administrator switches it on.

    public bool AdultEnabled { get; set; }

    public string AdultCategory { get; set; } = "adult";

    /// <summary>Where qBittorrent saves adult downloads; the same path is the Jellyfin library.</summary>
    public string AdultSavePath { get; set; } = "/data/media/adult";

    /// <summary>Where qBittorrent saves adult downloads when it sees the folder by another path
    /// (a qBittorrent on Windows: E:\XxX). Empty: <see cref="AdultSavePath"/>.</summary>
    public string AdultDownloadPath { get; set; } = string.Empty;

    public string AdultLibraryName { get; set; } = "Adult";

    public long AdultMinBytes { get; set; } = 20L * 1024 * 1024;

    public string AdultUnsafeRegex { get; set; } = @"\b(exe|scr|lnk|msi)\b";

    public string AdultCategories { get; set; } = "6000,6010,6020,6030,6040,6045,6050,6060,6070,6080,6090";

    /// <summary>Users the plugin switched from "all libraries" to an explicit list (to hide the adult library).</summary>
    public string[] ManagedUserIds { get; set; } = Array.Empty<string>();

    /// <summary>The libraries that existed at the last check; a library not in here is new.</summary>
    public string[] KnownLibraryIds { get; set; } = Array.Empty<string>();

    /// <summary>Non-administrators who may use Download Now within these limits (a "limited downloader").</summary>
    public UserLimit[] UserLimits { get; set; } = Array.Empty<UserLimit>();
}

/// <summary>Download limits for one non-administrator. 0 means no limit for that field.</summary>
public class UserLimit
{
    /// <summary>The Jellyfin user id, as Guid.ToString("N").</summary>
    public string UserId { get; set; } = string.Empty;

    public bool Enabled { get; set; }

    public int MaxMovieMb { get; set; }

    public int MaxEpisodeMb { get; set; }

    public int MoviesPerWeek { get; set; }

    public int EpisodesPerWeek { get; set; }
}
