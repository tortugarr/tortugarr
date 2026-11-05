using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Controller.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Lets a new Moonbase (the Moonfin server plugin the Tortugarr app is built on) in only when
/// it still has everything the app uses. Jellyfin used to update Moonbase straight from the
/// Moonfin repository; 2.5.0 (2026-10-30) dropped the "backdropEnabled" setting the app syncs.
///
/// Now the Moonfin repository is switched off and the Tortugarr repository (served by this
/// plugin, RepositoryController) lists Moonbase too, but only up to the approved version.
/// Twice a day this service reads the Moonfin manifest; a newer version is downloaded, its
/// checksum checked, and its DLL must contain every entry of moonbase-contract.txt (the
/// settings keys and /Moonfin routes the app uses) that the approved version contains. Then it
/// is approved and Jellyfin's own plugin updates install it; otherwise it is held back and the
/// reason is logged and kept in MoonbaseGateStatus.
/// </summary>
public sealed class MoonbaseGate : Microsoft.Extensions.Hosting.IHostedService
{
    internal const string UpstreamUrl = "https://raw.githubusercontent.com/Moonfin-Client/Plugin/master/manifest.json";
    internal const string MoonbaseName = "Moonbase";
    private const string DllName = "Moonfin.Server.dll";
    private static readonly TimeSpan Every = TimeSpan.FromHours(12);
    private static readonly object CacheLock = new();
    private static JsonObject? _upstreamPackage;

    private readonly IHttpClientFactory _httpFactory;
    private readonly IServerConfigurationManager _serverConfig;
    private readonly IApplicationPaths _paths;
    private readonly ILogger<MoonbaseGate> _log;
    private readonly AdminNotice _notice;
    private CancellationTokenSource? _stop;

    public MoonbaseGate(IHttpClientFactory httpFactory, IServerConfigurationManager serverConfig, IApplicationPaths paths, ILogger<MoonbaseGate> log, AdminNotice notice)
    {
        _httpFactory = httpFactory;
        _serverConfig = serverConfig;
        _paths = paths;
        _log = log;
        _notice = notice;
    }

    /// <summary>The contract: one entry per line, # for comments (generated from the app).</summary>
    internal static IReadOnlyList<string> Contract { get; } = LoadContract();

    private static IReadOnlyList<string> LoadContract()
    {
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("Jellyfin.Plugin.Tortugarr.Configuration.moonbase-contract.txt");
        if (s is null)
        {
            return Array.Empty<string>();
        }

        using var r = new StreamReader(s);
        return r.ReadToEnd().Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0 && !l.StartsWith('#')).ToArray();
    }

    /// <summary>The Moonbase package as the Tortugarr repository lists it: only versions up to the approved one, or null.</summary>
    internal static JsonObject? ApprovedPackage()
    {
        var approved = ParseVersion(Plugin.Instance?.Configuration.MoonbaseApprovedVersion);
        JsonObject? package;
        lock (CacheLock)
        {
            package = _upstreamPackage?.DeepClone() as JsonObject;
        }

        if (package is null || approved is null || Plugin.Instance?.Configuration.MoonbaseGateEnabled != true)
        {
            return null;
        }

        var kept = new JsonArray();
        foreach (var v in (package["versions"] as JsonArray ?? new JsonArray()).Where(v => v is not null))
        {
            if (ParseVersion((string?)v!["version"]) is { } ver && ver <= approved)
            {
                kept.Add(v.DeepClone());
            }
        }

        package["versions"] = kept;
        return kept.Count > 0 ? package : null;
    }

    /// <summary>
    /// What the candidate lacks: the contract entries found in the approved DLL but not in the
    /// candidate. Entries the approved version never had do not count (the app copes without them).
    /// </summary>
    internal static List<string> Missing(byte[] approvedDll, byte[] candidateDll, IEnumerable<string> contract)
    {
        var approved = Tokens(approvedDll);
        var candidate = Tokens(candidateDll);
        return contract.Where(approved.Contains).Where(c => !candidate.Contains(c)).Distinct().ToList();
    }

    /// <summary>The identifier-like runs of a DLL (attribute strings such as routes and JSON names are stored as UTF-8).</summary>
    internal static HashSet<string> Tokens(byte[] dll)
    {
        var set = new HashSet<string>(StringComparer.Ordinal);
        var sb = new StringBuilder();
        foreach (var b in dll)
        {
            var c = (char)b;
            if (b < 128 && (char.IsAsciiLetterOrDigit(c) || c is '_' or '/' or '-' or '{' or '}' or ':' or '.'))
            {
                sb.Append(c);
                continue;
            }

            Flush();
        }

        Flush();
        return set;

        void Flush()
        {
            if (sb.Length >= 3)
            {
                var s = sb.ToString();
                set.Add(s);
                // "Moonfin/Seerr/Api/{**path}" also counts as its parts' prefixes.
                foreach (var part in s.Split('/', StringSplitOptions.RemoveEmptyEntries))
                {
                    set.Add(part);
                }

                var segs = s.Split('/', StringSplitOptions.RemoveEmptyEntries);
                for (var i = 2; i <= segs.Length; i++)
                {
                    set.Add(string.Join('/', segs.Take(i)));
                }
            }

            sb.Clear();
        }
    }

    internal static Version? ParseVersion(string? v) =>
        Version.TryParse(v, out var parsed) ? parsed : null;

    /// <summary>Switches the Moonfin repository off and makes sure the Tortugarr one is on. True when something changed.</summary>
    internal static bool FixRepositories(List<MediaBrowser.Model.Updates.RepositoryInfo> repos)
    {
        var changed = false;
        foreach (var r in repos)
        {
            if (r.Url is { } url && url.Contains("Moonfin-Client/Plugin", StringComparison.OrdinalIgnoreCase) && r.Enabled)
            {
                r.Enabled = false;
                changed = true;
            }

            if (r.Url is { } own && own.Contains("/Tortugarr/v1/Repository/", StringComparison.OrdinalIgnoreCase) && !r.Enabled)
            {
                r.Enabled = true;
                changed = true;
            }
        }

        return changed;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _stop = new CancellationTokenSource();
        var token = _stop.Token;
        _ = Task.Run(async () =>
        {
            await Task.Delay(TimeSpan.FromMinutes(2), token).ConfigureAwait(false);
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await RunAsync(token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (Exception e)
                {
                    _log.LogWarning(e, "Tortugarr: Moonbase check failed");
                }

                await Task.Delay(Every, token).ConfigureAwait(false);
            }
        });
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _stop?.Cancel();
        return Task.CompletedTask;
    }

    internal async Task RunAsync(CancellationToken ct)
    {
        var plugin = Plugin.Instance;
        if (plugin is null || !plugin.Configuration.MoonbaseGateEnabled)
        {
            return;
        }

        var cfg = plugin.Configuration;
        var installed = InstalledVersions();
        if (installed.Count == 0)
        {
            return; // No Moonbase here: nothing to guard.
        }

        if (FixRepositories(_serverConfig.Configuration.PluginRepositories.ToList()))
        {
            _serverConfig.SaveConfiguration();
            _log.LogInformation("Tortugarr: Moonbase now updates only through the Tortugarr repository (Moonfin repository switched off)");
        }

        var http = _httpFactory.CreateClient("tortugarr");
        http.Timeout = TimeSpan.FromMinutes(5);
        var manifest = JsonNode.Parse(await http.GetStringAsync(UpstreamUrl, ct).ConfigureAwait(false)) as JsonArray;
        var package = manifest?.FirstOrDefault(p => (string?)p?["name"] == MoonbaseName) as JsonObject;
        if (package is null)
        {
            Status(plugin, "Moonfin manifest has no Moonbase package");
            return;
        }

        lock (CacheLock)
        {
            _upstreamPackage = (JsonObject)package.DeepClone();
        }

        var approved = ParseVersion(cfg.MoonbaseApprovedVersion);
        if (approved is null)
        {
            approved = installed.Keys.Max()!;
            cfg.MoonbaseApprovedVersion = approved.ToString();
            plugin.SaveConfiguration();
        }

        var candidates = (package["versions"] as JsonArray ?? new JsonArray())
            .Where(v => v is not null && ParseVersion((string?)v!["version"]) is { } ver && ver > approved)
            .Select(v => v!).OrderBy(v => ParseVersion((string?)v["version"])).ToList();
        if (candidates.Count == 0)
        {
            Status(plugin, $"Moonbase {approved} approved; nothing newer");
            return;
        }

        var approvedDll = installed.TryGetValue(approved, out var dir)
            ? await File.ReadAllBytesAsync(Path.Combine(dir, DllName), ct).ConfigureAwait(false)
            : await DownloadDll(http, (package["versions"] as JsonArray)?.FirstOrDefault(v => ParseVersion((string?)v?["version"]) == approved), ct).ConfigureAwait(false);
        if (approvedDll is null)
        {
            Status(plugin, $"Moonbase {approved}: approved DLL not found, nothing checked");
            return;
        }

        foreach (var c in candidates)
        {
            var version = (string)c["version"]!;
            var dll = await DownloadDll(http, c, ct).ConfigureAwait(false);
            if (dll is null)
            {
                Status(plugin, $"Moonbase {version} held back: download or checksum failed");
                await _notice.PostAsync("Moonbase", $"Moonbase {version} not installed yet",
                    "The download or its checksum failed; Tortugarr tries again in 12 hours. Nothing to do.", LogLevel.Information).ConfigureAwait(false);
                return;
            }

            var missing = Missing(approvedDll, dll, Contract);
            if (missing.Count > 0)
            {
                var msg = $"Moonbase {version} held back: it no longer has {string.Join(", ", missing.Take(20))} (used by the Tortugarr app)";
                _log.LogWarning("Tortugarr: {Message}", msg);
                Status(plugin, msg);
                await _notice.PostAsync("Moonbase", $"Moonbase {version} held back - Tortugarr update needed",
                    $"Moonbase {version} no longer has {string.Join(", ", missing.Take(20))}, which the Tortugarr app uses. "
                    + $"Moonbase stays on {cfg.MoonbaseApprovedVersion} until Tortugarr is updated for it. The app keeps working.",
                    LogLevel.Warning).ConfigureAwait(false);
                return;
            }

            cfg.MoonbaseApprovedVersion = version;
            approvedDll = dll;
            _log.LogInformation("Tortugarr: Moonbase {Version} approved (contract of {Count} entries kept)", version, Contract.Count);
            Status(plugin, $"Moonbase {version} approved");
            await _notice.PostAsync("Moonbase", $"Moonbase {version} approved",
                $"Moonbase {version} passed the Tortugarr check ({Contract.Count} settings and routes the app uses are all there). "
                + "Jellyfin installs it with its next plugin update; nothing to do.", LogLevel.Information).ConfigureAwait(false);
        }
    }

    private static void Status(Plugin plugin, string text)
    {
        plugin.Configuration.MoonbaseGateStatus = $"{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm}Z {text}";
        plugin.SaveConfiguration();
    }

    /// <summary>Installed Moonbase folders by version (Moonbase_3.0.0.0 -> 3.0.0.0), only those holding the DLL.</summary>
    private Dictionary<Version, string> InstalledVersions()
    {
        var found = new Dictionary<Version, string>();
        if (!Directory.Exists(_paths.PluginsPath))
        {
            return found;
        }

        foreach (var d in Directory.GetDirectories(_paths.PluginsPath, MoonbaseName + "_*"))
        {
            if (ParseVersion(Path.GetFileName(d)[(MoonbaseName.Length + 1)..]) is { } v && File.Exists(Path.Combine(d, DllName)))
            {
                found[v] = d;
            }
        }

        return found;
    }

    private async Task<byte[]?> DownloadDll(HttpClient http, JsonNode? version, CancellationToken ct)
    {
        if (version?["sourceUrl"] is not { } src)
        {
            return null;
        }

        try
        {
            var zip = await http.GetByteArrayAsync((string)src!, ct).ConfigureAwait(false);
            var checksum = (string?)version["checksum"];
            if (!string.IsNullOrWhiteSpace(checksum)
                && !string.Equals(Convert.ToHexString(MD5.HashData(zip)), checksum, StringComparison.OrdinalIgnoreCase))
            {
                _log.LogWarning("Tortugarr: Moonbase {Version} zip does not match its checksum", (string?)version["version"]);
                return null;
            }

            using var archive = new ZipArchive(new MemoryStream(zip), ZipArchiveMode.Read);
            var entry = archive.Entries.FirstOrDefault(e => e.Name.Equals(DllName, StringComparison.OrdinalIgnoreCase));
            if (entry is null)
            {
                return null;
            }

            using var ms = new MemoryStream();
            await using (var s = entry.Open())
            {
                await s.CopyToAsync(ms, ct).ConfigureAwait(false);
            }

            return ms.ToArray();
        }
        catch (Exception e) when (e is HttpRequestException or InvalidDataException or TaskCanceledException)
        {
            _log.LogWarning(e, "Tortugarr: Moonbase {Version} could not be downloaded", (string?)version["version"]);
            return null;
        }
    }
}
