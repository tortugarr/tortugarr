using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Keeps Seerr's 4K status in step with the library.
///
/// 2026-11-12: Seerr tracks a separate 4K status that only a dedicated 4K Radarr/Sonarr moves.
/// Tortugarr runs one Radarr and one Sonarr for every quality, so a request made as 4K stayed
/// "Requested" in Seerr (tabs, web page, notifications) although the title was in the library
/// (Rocky II, Training Day, Blade Runner 2049 …).
///
/// Every 10 minutes this service marks the 4K status available (or partly available) wherever
/// the title itself is, so old requests are cleaned up and new ones follow on their own.
/// </summary>
public sealed class SeerrFourKSync : Microsoft.Extensions.Hosting.IHostedService
{
    private static readonly TimeSpan Every = TimeSpan.FromMinutes(10);
    private readonly TortugarrService _svc;
    private readonly ILogger<SeerrFourKSync> _log;
    private CancellationTokenSource? _stop;

    public SeerrFourKSync(TortugarrService svc, ILogger<SeerrFourKSync> log)
    {
        _svc = svc;
        _log = log;
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
                    await SyncAsync(token).ConfigureAwait(false);
                }
                catch (OperationCanceledException) when (token.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception e)
                {
                    _log.LogWarning(e, "Tortugarr: Seerr 4K status sync failed");
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

    private static Configuration.PluginConfiguration Cfg => Plugin.Instance?.Configuration ?? new Configuration.PluginConfiguration();

    private async Task SyncAsync(CancellationToken ct)
    {
        var c = Cfg;
        if (string.IsNullOrWhiteSpace(c.SeerrUrl) || string.IsNullOrWhiteSpace(c.SeerrApiKey))
        {
            return;
        }

        var seerr = _svc.Seerr;
        var fixedCount = 0;
        foreach (var filter in new[] { "available", "partial" })
        {
            for (var skip = 0; skip < 5000; skip += 100)
            {
                var page = await seerr.Get($"/media?take=100&skip={skip}&filter={filter}", ct).ConfigureAwait(false);
                var results = page?["results"] as JsonArray ?? new JsonArray();
                foreach (var (id, status) in Stuck4K(results))
                {
                    await seerr.Post($"/media/{id}/{status}", new JsonObject { ["is4k"] = true }, ct).ConfigureAwait(false);
                    fixedCount++;
                }

                if (results.Count < 100)
                {
                    break;
                }
            }
        }

        if (fixedCount > 0)
        {
            _log.LogInformation("Tortugarr: marked the 4K status of {Count} title(s) in Seerr as available (one library for every quality)", fixedCount);
        }
    }

    /// <summary>
    /// Media whose 4K status is pending (2) or processing (3) while the title itself is available
    /// (5) or partly available (4): Seerr id and the status to set ("available" / "partial").
    /// Deleted (7) and blocklisted (6) 4K statuses are left alone.
    /// </summary>
    internal static List<(int Id, string Status)> Stuck4K(JsonArray media) => media
        .OfType<JsonObject>()
        .Select(m => (Id: (int?)m["id"] ?? 0, Status: (int?)m["status"] ?? 0, Status4k: (int?)m["status4k"] ?? 0))
        .Where(m => m.Id > 0 && (m.Status4k == 2 || m.Status4k == 3) && (m.Status == 5 || m.Status == 4))
        .Select(m => (m.Id, m.Status == 5 ? "available" : "partial"))
        .ToList();
}
