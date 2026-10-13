using Jellyfin.Data.Events.Users;
using MediaBrowser.Controller.Events;
using MediaBrowser.Controller.Entities;
using MediaBrowser.Controller.Library;
using MediaBrowser.Controller.Providers;
using MediaBrowser.Model.Configuration;
using MediaBrowser.Model.Entities;
using MediaBrowser.Model.IO;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// The adult library (spec 3.9): its own Jellyfin library, created only when an administrator
/// switched the feature on, and hidden from every non-administrator - including users created
/// later. Administrators grant access per user in Jellyfin.
/// </summary>
public sealed class AdultLibraryService
{
    private readonly ILibraryManager _library;
    private readonly IUserManager _users;
    private readonly IProviderManager _providers;
    private readonly IFileSystem _fileSystem;
    private readonly ILogger<AdultLibraryService> _log;
    private readonly SemaphoreSlim _lock = new(1, 1);

    public AdultLibraryService(ILibraryManager library, IUserManager users, IProviderManager providers, IFileSystem fileSystem, ILogger<AdultLibraryService> log)
    {
        _library = library;
        _users = users;
        _providers = providers;
        _fileSystem = fileSystem;
        _log = log;
    }

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    /// <summary>The library's id, or null when it does not exist.</summary>
    public Guid? LibraryId()
    {
        var f = _library.GetVirtualFolders().FirstOrDefault(v => v.Locations.Any(l => PathEq(l, Cfg.AdultSavePath)));
        return f is not null && Guid.TryParse(f.ItemId, out var id) ? id : null;
    }

    /// <summary>True when a library item is the adult library (by its folder, which works before Jellyfin lists it).</summary>
    public static bool IsAdult(CollectionFolder folder) => folder.PhysicalLocations.Any(l => PathEq(l, Cfg.AdultSavePath));

    /// <summary>
    /// Scans the adult library, like "Scan library" in Jellyfin. Nothing else tells Jellyfin about a
    /// finished adult download (there is no *arr behind it), and its folder watcher did not see one.
    /// A library made on an empty folder has no folder item yet (Jellyfin skips empty library
    /// folders), so the scan alone would find nothing: the top level is validated first. That only
    /// lists the library folders themselves, it does not scan their contents.
    /// </summary>
    public async Task RescanAsync()
    {
        if (Cfg.AdultEnabled && LibraryId() is Guid id)
        {
            await _library.ValidateTopLibraryFolders(CancellationToken.None).ConfigureAwait(false);
            _providers.QueueRefresh(id, new MetadataRefreshOptions(new DirectoryService(_fileSystem)) { IsAutomated = true }, RefreshPriority.High);
            _log.LogInformation("Tortugarr: adult library scan queued");
        }
    }

    private static bool PathEq(string a, string b) => string.Equals(a.TrimEnd('/'), b.TrimEnd('/'), StringComparison.Ordinal);

    /// <summary>Creates the library (once) and hides it from non-administrators. Idempotent.</summary>
    public async Task EnsureAsync()
    {
        if (!Cfg.AdultEnabled)
        {
            return;
        }

        await _lock.WaitAsync().ConfigureAwait(false);
        try
        {
            if (LibraryId() is null)
            {
                if (!Directory.Exists(Cfg.AdultSavePath))
                {
                    throw new NotConfiguredException($"the adult folder {Cfg.AdultSavePath} (made by the Tortugarr installer)");
                }

                var options = new LibraryOptions
                {
                    EnableRealtimeMonitor = true,
                    EnableInternetProviders = false,
                    SaveLocalMetadata = false,
                    EnableChapterImageExtraction = false,
                    EnableTrickplayImageExtraction = false,
                    PathInfos = new[] { new MediaPathInfo(Cfg.AdultSavePath) },
                };
                await _library.AddVirtualFolder(Cfg.AdultLibraryName, CollectionTypeOptions.homevideos, options, true).ConfigureAwait(false);
                _log.LogInformation("Tortugarr: adult library created on {Path}", Cfg.AdultSavePath);
            }

            var id = LibraryId();
            if (id is null)
            {
                return;
            }

            foreach (var user in _users.GetUsers().ToList())
            {
                await HideFrom(user.Id, id.Value).ConfigureAwait(false);
            }

            // The starting point only, once; after that only AddNewLibrariesAsync moves it, after it
            // has given the new libraries to the users - otherwise a new library could be marked as
            // known before anyone got it.
            if (Cfg.KnownLibraryIds.Length == 0)
            {
                RememberLibraries();
            }
        }
        finally
        {
            _lock.Release();
        }
    }

    /// <summary>The user's list holds every ordinary library known so far (and maybe the adult one).</summary>
    internal static bool AllExceptAdult(IReadOnlyCollection<Guid> ordinary, IEnumerable<Guid> enabled)
    {
        var set = enabled.ToHashSet();
        return ordinary.Count > 0 && ordinary.All(set.Contains);
    }

    /// <summary>A non-administrator who sees "all libraries" is switched to "all libraries except this one".</summary>
    public async Task HideFrom(Guid userId, Guid libraryId)
    {
        var user = _users.GetUserById(userId);
        if (user is null)
        {
            return;
        }

        var policy = _users.GetUserDto(user, null).Policy;
        if (policy.IsAdministrator || !policy.EnableAllFolders)
        {
            return; // admins see everything; users with an explicit list are left as the admin set them
        }

        policy.EnableAllFolders = false;
        policy.EnabledFolders = _library.GetVirtualFolders()
            .Select(v => Guid.TryParse(v.ItemId, out var g) ? g : Guid.Empty)
            .Where(g => g != Guid.Empty && g != libraryId)
            .ToArray();
        await _users.UpdatePolicyAsync(userId, policy).ConfigureAwait(false);
        Remember(userId);
        _log.LogInformation("Tortugarr: adult library hidden from user {User}", user.Username);
    }

    private static void Remember(Guid userId)
    {
        var plugin = Plugin.Instance;
        if (plugin is null || plugin.Configuration.ManagedUserIds.Contains(userId.ToString("N")))
        {
            return;
        }

        plugin.Configuration.ManagedUserIds = plugin.Configuration.ManagedUserIds.Append(userId.ToString("N")).ToArray();
        plugin.SaveConfiguration();
    }

    private Guid[] AllLibraryIds() => _library.GetVirtualFolders()
        .Select(v => Guid.TryParse(v.ItemId, out var g) ? g : Guid.Empty).Where(g => g != Guid.Empty).ToArray();

    private void RememberLibraries(IEnumerable<Guid>? ids = null)
    {
        var plugin = Plugin.Instance;
        if (plugin is null)
        {
            return;
        }

        plugin.Configuration.KnownLibraryIds = (ids ?? AllLibraryIds()).Where(g => g != Guid.Empty).Distinct().Select(g => g.ToString("N")).ToArray();
        plugin.SaveConfiguration();
    }

    /// <summary>
    /// A library made after the adult library existed would be missing from the users we switched to
    /// an explicit list. Every library that is new since the last check is added for them. What an
    /// administrator changed by hand on the existing libraries is left as it is.
    /// </summary>
    /// <param name="added">
    /// The library from Jellyfin's ItemAdded event. Jellyfin raises the event before the library shows
    /// up in GetVirtualFolders (seen in the lab: the new id came only with the next library), so its id
    /// is taken from the event itself.
    /// </param>
    public async Task AddNewLibrariesAsync(Guid? added = null)
    {
        if (!Cfg.AdultEnabled || LibraryId() is not Guid adult)
        {
            return;
        }

        await _lock.WaitAsync().ConfigureAwait(false);
        try
        {
            var known = Cfg.KnownLibraryIds.Select(s => Guid.TryParse(s, out var g) ? g : Guid.Empty).ToHashSet();
            var all = AllLibraryIds();
            if (added is Guid a && !all.Contains(a))
            {
                all = all.Append(a).ToArray();
            }

            var fresh = all.Where(g => g != adult && !known.Contains(g)).ToArray();
            if (fresh.Length == 0)
            {
                return;
            }

            // Who gets them: the users the plugin switched from "all libraries", and anyone - also an
            // administrator who hid the adult library for himself in the app - whose list is every
            // ordinary library known so far ("all except adult"). A list an administrator narrowed
            // by hand does not match, and is left alone.
            var ordinary = known.Where(g => g != adult && all.Contains(g)).ToList();
            foreach (var user in _users.GetUsers().ToList())
            {
                var userId = user.Id;
                var policy = _users.GetUserDto(user, null).Policy;
                if (policy.EnableAllFolders)
                {
                    continue;
                }

                var managed = !policy.IsAdministrator && Cfg.ManagedUserIds.Contains(userId.ToString("N"));
                if (!managed && !AllExceptAdult(ordinary, policy.EnabledFolders))
                {
                    continue;
                }

                var add = fresh.Where(g => !policy.EnabledFolders.Contains(g)).ToArray();
                if (add.Length > 0)
                {
                    policy.EnabledFolders = policy.EnabledFolders.Concat(add).ToArray();
                    await _users.UpdatePolicyAsync(userId, policy).ConfigureAwait(false);
                    _log.LogInformation("Tortugarr: {Count} new library/libraries made visible to user {User}", add.Length, user.Username);
                }
            }

            // Exactly the libraries handed out above (plus the old ones), not a fresh read: a library
            // that appeared meanwhile must stay "new" for the next event or start-up check.
            RememberLibraries(known.Concat(all));
        }
        finally
        {
            _lock.Release();
        }
    }
}

/// <summary>
/// A new ordinary library becomes visible to the users the plugin converted from "all libraries"
/// (see AddNewLibrariesAsync). Driven by Jellyfin's own ItemAdded event for libraries, plus one
/// check after start-up as a safety net for libraries added while the plugin was not running.
/// </summary>
public sealed class NewLibraryWatcher : Microsoft.Extensions.Hosting.IHostedService
{
    private readonly AdultLibraryService _adult;
    private readonly ILibraryManager _library;
    private readonly ILogger<NewLibraryWatcher> _log;
    private CancellationTokenSource? _stop;

    public NewLibraryWatcher(AdultLibraryService adult, ILibraryManager library, ILogger<NewLibraryWatcher> log)
    {
        _adult = adult;
        _library = library;
        _log = log;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _library.ItemAdded += OnItemAdded;
        _stop = new CancellationTokenSource();
        var token = _stop.Token;
        _ = Task.Run(async () =>
        {
            try
            {
                // Safety net once Jellyfin has finished starting and loading its libraries.
                await Task.Delay(TimeSpan.FromSeconds(30), token).ConfigureAwait(false);
                await _adult.AddNewLibrariesAsync().ConfigureAwait(false);
                await _adult.RescanAsync().ConfigureAwait(false); // an adult download that finished while Jellyfin was down
            }
            catch (OperationCanceledException)
            {
            }
            catch (Exception e)
            {
                _log.LogWarning(e, "Tortugarr: start-up check for new libraries failed");
            }
        });
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _library.ItemAdded -= OnItemAdded;
        _stop?.Cancel();
        return Task.CompletedTask;
    }

    private void OnItemAdded(object? sender, ItemChangeEventArgs e)
    {
        if (e.Item is not CollectionFolder folder || AdultLibraryService.IsAdult(folder))
        {
            return; // only a new ordinary library matters, not every new movie or episode
        }

        var id = folder.Id;
        _ = Task.Run(async () =>
        {
            try
            {
                await _adult.AddNewLibrariesAsync(id).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "Tortugarr: giving a new library to the converted users failed");
            }
        });
    }
}

/// <summary>New users must not see the adult library until an administrator allows it.</summary>
public sealed class HideAdultFromNewUsers : IEventConsumer<UserCreatedEventArgs>
{
    private readonly AdultLibraryService _adult;

    public HideAdultFromNewUsers(AdultLibraryService adult)
    {
        _adult = adult;
    }

    public async Task OnEvent(UserCreatedEventArgs eventArgs)
    {
        if (_adult.LibraryId() is Guid id)
        {
            await _adult.HideFrom(eventArgs.Argument.Id, id).ConfigureAwait(false);
        }
    }
}
