using Jellyfin.Data.Events.Users;
using Jellyfin.Plugin.Tortugarr.Services;
using MediaBrowser.Controller;
using MediaBrowser.Controller.Events;
using MediaBrowser.Controller.Plugins;
using Microsoft.Extensions.DependencyInjection;

namespace Jellyfin.Plugin.Tortugarr;

/// <summary>Registers the plugin's services with Jellyfin.</summary>
public class PluginServiceRegistrator : IPluginServiceRegistrator
{
    public void RegisterServices(IServiceCollection serviceCollection, IServerApplicationHost applicationHost)
    {
        // Cookies are handled by hand (qBittorrent's session cookie); the default handler would
        // swallow Set-Cookie into its own container and hide it from the code.
        serviceCollection.AddHttpClient("tortugarr")
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { UseCookies = false });
        // Indexer links can redirect to a magnet: link, which must be read, not followed.
        serviceCollection.AddHttpClient("tortugarr-noredirect")
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { UseCookies = false, AllowAutoRedirect = false });
        serviceCollection.AddSingleton<TortugarrService>();
        serviceCollection.AddSingleton<UserLimitService>();
        serviceCollection.AddSingleton<SettingsService>();
        serviceCollection.AddSingleton<AdultLibraryService>();
        serviceCollection.AddScoped<IEventConsumer<UserCreatedEventArgs>, HideAdultFromNewUsers>();
        serviceCollection.AddHostedService<NewLibraryWatcher>();
        serviceCollection.AddSingleton<SeerrSync>();
        serviceCollection.AddSingleton<LibraryDeleteService>();
        serviceCollection.AddHostedService<RemovedItemWatcher>();
        serviceCollection.AddSingleton<ArrHookService>();
        serviceCollection.AddSingleton<SeriesService>();
        serviceCollection.AddSingleton<SpaceService>();
        serviceCollection.AddHostedService<FlareSolverrTagger>();
    }
}
