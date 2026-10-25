using Jellyfin.Plugin.Tortugarr.Configuration;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Serialization;

namespace Jellyfin.Plugin.Tortugarr;

/// <summary>
/// Tortugarr: Download Now, downloads, disk space, video check and subtitles for the Tortugarr
/// app, done on the server so the app never holds a Sonarr/Radarr/Prowlarr/Bazarr key.
/// </summary>
public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
{
    public Plugin(IApplicationPaths applicationPaths, IXmlSerializer xmlSerializer)
        : base(applicationPaths, xmlSerializer)
    {
        Instance = this;
    }

    public static Plugin? Instance { get; private set; }

    public override string Name => "Tortugarr";

    public override Guid Id => Guid.Parse("19f30fb1-bb78-444b-a75e-2997883b215c");

    /// <summary>The settings page (Dashboard > Plugins > Tortugarr): connections, download limits, downloads, adult library, filters.</summary>
    public IEnumerable<PluginPageInfo> GetPages() => new[]
    {
        new PluginPageInfo { Name = Name, EmbeddedResourcePath = GetType().Namespace + ".Configuration.configPage.html" },
    };

    public override string Description => "Server side of the Tortugarr app: searches, downloads and subtitles through Sonarr, Radarr and Bazarr.";
}
