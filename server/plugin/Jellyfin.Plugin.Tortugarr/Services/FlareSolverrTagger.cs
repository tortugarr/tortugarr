using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Gives every Prowlarr indexer the tag of the FlareSolverr proxy the installer set up.
/// Prowlarr only sends an indexer through a proxy with a matching tag, and users adding
/// 1337x did not know that the tag was needed (2026-10-21). FlareSolverr only steps in when
/// a reply is a Cloudflare challenge, so the tag changes nothing for any other site, and a
/// site that turns Cloudflare on later keeps working.
/// </summary>
public sealed class FlareSolverrTagger : Microsoft.Extensions.Hosting.IHostedService
{
    private static readonly TimeSpan Every = TimeSpan.FromMinutes(3);
    private readonly TortugarrService _svc;
    private readonly ILogger<FlareSolverrTagger> _log;
    private CancellationTokenSource? _stop;

    public FlareSolverrTagger(TortugarrService svc, ILogger<FlareSolverrTagger> log)
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
            await Task.Delay(TimeSpan.FromMinutes(1), token).ConfigureAwait(false);
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await TagAsync(token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (Exception e)
                {
                    _log.LogDebug(e, "Tortugarr: FlareSolverr tags not checked");
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

    private async Task TagAsync(CancellationToken ct)
    {
        var cfg = Plugin.Instance?.Configuration;
        if (cfg is null)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(cfg.ProwlarrUrl) || string.IsNullOrWhiteSpace(cfg.ProwlarrApiKey))
        {
            return;
        }

        var prowlarr = _svc.Prowlarr;
        var tag = ProxyTag(
            await prowlarr.Get("/indexerproxy", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray());
        if (tag is null)
        {
            return;
        }

        var indexers = await prowlarr.Get("/indexer", ct).ConfigureAwait(false) as JsonArray ?? new JsonArray();
        foreach (var indexer in Untagged(indexers, tag.Value))
        {
            var tags = indexer["tags"] as JsonArray ?? new JsonArray();
            tags.Add(tag.Value);
            indexer["tags"] = tags;
            // forceSave: no test of the indexer, so one that is down right now is tagged too.
            await prowlarr.Put($"/indexer/{(int)indexer["id"]!}?forceSave=true", indexer, ct).ConfigureAwait(false);
            _log.LogInformation("Tortugarr: indexer {Name} goes through FlareSolverr when Cloudflare blocks it", (string?)indexer["name"]);
        }
    }

    /// <summary>The tag of the FlareSolverr proxy, or null without one (or one without tags).</summary>
    internal static int? ProxyTag(JsonArray proxies) =>
        proxies.Where(p => p is not null && string.Equals((string?)p!["implementation"], "FlareSolverr", StringComparison.OrdinalIgnoreCase))
            .SelectMany(p => (p!["tags"] as JsonArray ?? new JsonArray()).Select(t => (int?)t))
            .FirstOrDefault(t => t is not null);

    /// <summary>Indexers (copies) that lack the tag.</summary>
    internal static List<JsonNode> Untagged(JsonArray indexers, int tag) =>
        indexers.Where(i => i is not null && !(i!["tags"] as JsonArray ?? new JsonArray()).Any(t => (int?)t == tag))
            .Select(i => i!.DeepClone())
            .ToList();
}
