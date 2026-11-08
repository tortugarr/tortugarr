using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using MediaBrowser.Controller.Library;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// One look at the whole server for the app's admin dashboard (2026-11-08): is every service
/// up (and which version), how full is each library disk, and what Radarr, Sonarr and Prowlarr
/// warn about. The user found broken things only by chance; this puts them on one card.
/// </summary>
public sealed class HealthService
{
    // Below these a disk is a warning / an error: a 4K film needs 20-60 GB.
    internal const long WarnFreeBytes = 25L << 30;
    internal const long ErrorFreeBytes = 2L << 30;
    private static readonly TimeSpan ProbeTimeout = TimeSpan.FromSeconds(8);

    // Radarr's root-folder warning is how Tortugarr lays out downloads on purpose.
    private static readonly HashSet<string> IgnoredSources = new(StringComparer.OrdinalIgnoreCase) { "DownloadClientRootFolderCheck" };

    private readonly TortugarrService _svc;
    private readonly ILibraryManager _library;
    private readonly ILogger<HealthService> _log;

    public HealthService(TortugarrService svc, ILibraryManager library, ILogger<HealthService> log)
    {
        _svc = svc;
        _library = library;
        _log = log;
    }

    public async Task<object> CheckAsync(CancellationToken ct)
    {
        var c = Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();
        bool Has(string url) => !string.IsNullOrWhiteSpace(url);

        var probes = new List<Task<ServiceState>>();
        if (Has(c.RadarrUrl)) probes.Add(Probe("radarr", "Radarr", async t => (string?)(await _svc.Radarr.Get("/system/status", t, 8).ConfigureAwait(false))?["version"], ct));
        if (Has(c.SonarrUrl)) probes.Add(Probe("sonarr", "Sonarr", async t => (string?)(await _svc.Sonarr.Get("/system/status", t, 8).ConfigureAwait(false))?["version"], ct));
        if (Has(c.ProwlarrUrl)) probes.Add(Probe("prowlarr", "Prowlarr", async t => (string?)(await _svc.Prowlarr.Get("/system/status", t, 8).ConfigureAwait(false))?["version"], ct));
        if (TortugarrService.HasTorrentClient(c)) probes.Add(Probe(c.DownloadClientType, _svc.Qbit.Name, async t => await _svc.Qbit.Version(t).ConfigureAwait(false), ct));
        if (Has(c.BazarrUrl)) probes.Add(Probe("bazarr", "Bazarr", async t => (string?)(await _svc.Bazarr.Get("/system/status", t, 8).ConfigureAwait(false))?["data"]?["bazarr_version"], ct));
        if (Has(c.SeerrUrl)) probes.Add(Probe("seerr", "Seerr", async t => (string?)(await _svc.Seerr.Get("/settings/about", t, 8).ConfigureAwait(false))?["version"], ct));

        var warnings = new List<Task<List<HealthWarning>>>();
        if (Has(c.RadarrUrl)) warnings.Add(ArrWarnings("Radarr", () => _svc.Radarr, ct));
        if (Has(c.SonarrUrl)) warnings.Add(ArrWarnings("Sonarr", () => _svc.Sonarr, ct));
        if (Has(c.ProwlarrUrl)) warnings.Add(ArrWarnings("Prowlarr", () => _svc.Prowlarr, ct));

        var disks = Disks();
        var services = await Task.WhenAll(probes).ConfigureAwait(false);
        var found = (await Task.WhenAll(warnings).ConfigureAwait(false)).SelectMany(w => w).ToList();
        return new
        {
            checkedAt = DateTimeOffset.UtcNow,
            overall = Overall(services, disks, found),
            services,
            disks,
            warnings = found,
        };
    }

    private async Task<ServiceState> Probe(string id, string name, Func<CancellationToken, Task<string?>> version, CancellationToken ct)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(ProbeTimeout);
        try
        {
            return new ServiceState(id, name, true, await version(cts.Token).ConfigureAwait(false) ?? string.Empty, null);
        }
        catch (Exception e) when (!ct.IsCancellationRequested)
        {
            _log.LogDebug(e, "Tortugarr health: {Name} did not answer", name);
            var why = e is OperationCanceledException ? "no answer within 8 seconds" : e is NotConfiguredException ? "address or key missing" : e.Message;
            return new ServiceState(id, name, false, string.Empty, why);
        }
    }

    private async Task<List<HealthWarning>> ArrWarnings(string app, Func<ArrClient> client, CancellationToken ct)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(ProbeTimeout);
        try
        {
            return FromArrHealth(app, await client().Get("/health", cts.Token, 8).ConfigureAwait(false) as JsonArray);
        }
        catch (Exception e) when (!ct.IsCancellationRequested)
        {
            _log.LogDebug(e, "Tortugarr health: no health list from {App}", app);
            return new(); // the service probe already says it is down
        }
    }

    /// <summary>Radarr/Sonarr/Prowlarr health entries worth showing; update notices count as info.</summary>
    internal static List<HealthWarning> FromArrHealth(string app, JsonArray? items)
    {
        var list = new List<HealthWarning>();
        foreach (var h in items ?? new JsonArray())
        {
            var source = (string?)h?["source"] ?? string.Empty;
            var type = ((string?)h?["type"] ?? string.Empty).ToLowerInvariant();
            var message = (string?)h?["message"] ?? string.Empty;
            if (IgnoredSources.Contains(source) || string.IsNullOrWhiteSpace(message) || type is "ok" or "notice")
            {
                continue;
            }

            var level = source.Contains("Update", StringComparison.OrdinalIgnoreCase) ? "info" : type == "error" ? "error" : "warning";
            list.Add(new HealthWarning(app, level, message));
        }

        return list;
    }

    private List<DiskState> Disks()
    {
        Dictionary<string, MountPoint> mounts;
        try
        {
            mounts = ParseMountInfo(File.ReadLines("/proc/self/mountinfo"));
        }
        catch (Exception e)
        {
            _log.LogDebug(e, "Tortugarr health: no mount table");
            mounts = new();
        }

        var folders = new List<LibraryFolder>();
        // Collections (boxsets) live in Jellyfin's own config folder, not on a library disk.
        foreach (var v in _library.GetVirtualFolders().Where(v => !string.Equals(v.CollectionType?.ToString(), "boxsets", StringComparison.OrdinalIgnoreCase)))
        {
            foreach (var path in v.Locations)
            {
                try
                {
                    var d = new DriveInfo(path);
                    folders.Add(new LibraryFolder(v.Name, path, d.AvailableFreeSpace, d.TotalSize, MountOf(mounts, path)));
                }
                catch (Exception e)
                {
                    _log.LogDebug(e, "Tortugarr health: no size for {Path}", path);
                }
            }
        }

        return BuildDisks(folders);
    }

    /// <summary>Mount point -> device and source ("E:" for a Windows drive under WSL), from /proc/self/mountinfo.</summary>
    internal static Dictionary<string, MountPoint> ParseMountInfo(IEnumerable<string> lines)
    {
        var map = new Dictionary<string, MountPoint>(StringComparer.Ordinal);
        foreach (var line in lines)
        {
            var dash = line.IndexOf(" - ", StringComparison.Ordinal);
            var f = line.Split(' ');
            if (dash < 0 || f.Length < 5)
            {
                continue;
            }

            var after = line[(dash + 3)..].Split(' ');
            var source = after.Length > 1 ? after[1].Replace("\\134", "\\", StringComparison.Ordinal) : string.Empty;
            var letter = Regex.Match(source, @"^([A-Za-z]):");
            map[f[4]] = new MountPoint(f[2], letter.Success ? letter.Groups[1].Value.ToUpperInvariant() + ":" : null);
        }

        return map;
    }

    internal static MountPoint? MountOf(Dictionary<string, MountPoint> mounts, string path) =>
        mounts.Where(m => path == m.Key || path.StartsWith(m.Key.TrimEnd('/') + "/", StringComparison.Ordinal))
            .OrderByDescending(m => m.Key.Length).Select(m => (MountPoint?)m.Value).FirstOrDefault();

    /// <summary>Library folders on the same disk become one entry, named by drive letter when known.</summary>
    internal static List<DiskState> BuildDisks(IEnumerable<LibraryFolder> folders) =>
        folders.GroupBy(f => f.Mount?.Device ?? $"{f.TotalBytes}/{f.FreeBytes}")
            .Select(g =>
            {
                var first = g.First();
                var free = first.FreeBytes;
                var level = free < ErrorFreeBytes ? "error" : free < WarnFreeBytes || (first.TotalBytes > 0 && free < first.TotalBytes / 20) ? "warning" : "ok";
                return new DiskState(first.Mount?.Drive, g.Select(f => f.Library).Distinct().ToList(), free, first.TotalBytes, level);
            })
            .OrderBy(d => d.Drive ?? "~").ToList();

    internal static string Overall(IEnumerable<ServiceState> services, IEnumerable<DiskState> disks, IEnumerable<HealthWarning> warnings)
    {
        var levels = services.Select(s => s.Ok ? "ok" : "error")
            .Concat(disks.Select(d => d.Level))
            .Concat(warnings.Select(w => w.Level == "info" ? "ok" : w.Level)).ToList();
        return levels.Contains("error") ? "error" : levels.Contains("warning") ? "warning" : "ok";
    }
}

internal sealed record ServiceState(string Id, string Name, bool Ok, string Version, string? Message);

internal sealed record HealthWarning(string Source, string Level, string Message);

internal sealed record DiskState(string? Drive, List<string> Libraries, long FreeBytes, long TotalBytes, string Level);

internal sealed record MountPoint(string Device, string? Drive);

internal sealed record LibraryFolder(string Library, string Path, long FreeBytes, long TotalBytes, MountPoint? Mount);
