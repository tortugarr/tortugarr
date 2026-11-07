using System.Text.Json.Nodes;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Tortugarr.Services;

/// <summary>
/// Repairs torrents that qBittorrent shows as 100 % but never finishes.
/// qBittorrent 5.3 / libtorrent 2.1 on 2026-11-05 lost track of which pieces it had: progress
/// above 1.0, a negative amount left, "Unexpected data detected" in its log, file progress of a
/// few percent and no completion, so the finish hook never ran and Sonarr waited forever.
/// A recheck fixes it, but in the running client the recheck may hang in checkingResumeData
/// and only runs after a restart. The watchdog rechecks such torrents and, when allowed
/// (QbitWatchdogRestart, needs the Windows keepalive task), closes qBittorrent once the
/// recheck hangs, so nobody has to walk to the PC.
///
/// It also nudges downloads that stop moving (QbitStallNudge, 2026-11-07): a torrent sat
/// "stalled" at 59.7 % with ten seeds announced, because the few seeds it reached would not
/// send to it. Asking the trackers for fresh peers got it going. After 15 minutes without new
/// data the watchdog does that; after 30 it stops and starts the torrent so every connection
/// is made fresh. Torrents the user stopped, forced, queued or finished are never touched.
/// </summary>
public sealed class QbitWatchdog : Microsoft.Extensions.Hosting.IHostedService
{
    internal static readonly TimeSpan Every = TimeSpan.FromMinutes(3);
    internal static readonly TimeSpan HangAfter = TimeSpan.FromMinutes(10);
    internal static readonly TimeSpan RecheckAgainAfter = TimeSpan.FromMinutes(30);
    internal static readonly TimeSpan RestartAgainAfter = TimeSpan.FromMinutes(30);
    internal static readonly TimeSpan StallAfter = TimeSpan.FromMinutes(15);
    internal static readonly TimeSpan ReannounceAgainAfter = TimeSpan.FromMinutes(30);
    internal static readonly TimeSpan BounceAfter = TimeSpan.FromMinutes(30);
    internal static readonly TimeSpan BounceAgainAfter = TimeSpan.FromHours(2);

    private static readonly HashSet<string> DownloadStates = new(StringComparer.Ordinal)
    {
        "downloading", "stalledDL", "forcedDL", "queuedDL", "metaDL", "forcedMetaDL",
    };

    private readonly TortugarrService _svc;
    private readonly ILogger<QbitWatchdog> _log;
    private readonly AdminNotice _notice;
    private readonly WatchdogState _state = new();
    private CancellationTokenSource? _stop;

    public QbitWatchdog(TortugarrService svc, ILogger<QbitWatchdog> log, AdminNotice notice)
    {
        _svc = svc;
        _log = log;
        _notice = notice;
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
                    _log.LogDebug(e, "Tortugarr: qBittorrent watchdog pass skipped");
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

    private async Task RunAsync(CancellationToken ct)
    {
        var cfg = Plugin.Instance?.Configuration;
        if (cfg is null || !cfg.QbitWatchdogEnabled || cfg.DownloadClientType != "qbittorrent" || string.IsNullOrWhiteSpace(cfg.DownloadClientUrl))
        {
            return;
        }

        var qbit = _svc.Qbit;
        var torrents = await qbit.ListAll(ct).ConfigureAwait(false);
        var plan = Decide(torrents, _state, DateTimeOffset.UtcNow, cfg.QbitWatchdogRestart);
        if (plan.Recheck.Count > 0)
        {
            await qbit.Recheck(plan.Recheck, ct).ConfigureAwait(false);
            Report($"rechecked {plan.Recheck.Count} torrent(s) stuck at 100 %: {string.Join(", ", plan.RecheckNames)}");
            await _notice.PostAsync("Qbit", $"Download repaired: {string.Join(", ", plan.RecheckNames)}",
                "qBittorrent showed 100 % but never finished; Tortugarr asked it to check the files again. Nothing to do.",
                LogLevel.Information).ConfigureAwait(false);
        }

        if (cfg.QbitStallNudge)
        {
            await NudgeAsync(qbit, torrents, plan.Restart, ct).ConfigureAwait(false);
        }

        if (plan.Restart)
        {
            await qbit.Shutdown(ct).ConfigureAwait(false);
            Report($"closed qBittorrent for a restart: the recheck of {string.Join(", ", plan.HungNames)} hung");
            await _notice.PostAsync("Qbit", "qBittorrent restarted",
                $"The file check of {string.Join(", ", plan.HungNames)} hung; Tortugarr closed qBittorrent so it starts fresh.",
                LogLevel.Warning).ConfigureAwait(false);
        }
    }

    private async Task NudgeAsync(QbitClient qbit, JsonArray torrents, bool restarting, CancellationToken ct)
    {
        if (restarting)
        {
            return; // qBittorrent is about to close; every connection starts fresh anyway
        }

        var nudge = DecideStalls(torrents, _state.Stalls, DateTimeOffset.UtcNow);
        if (nudge.Reannounce.Count > 0)
        {
            await qbit.Reannounce(nudge.Reannounce, ct).ConfigureAwait(false);
            _log.LogInformation("Tortugarr: asked for fresh peers for stalled download(s): {Names}", string.Join(", ", nudge.ReannounceNames));
        }

        if (nudge.Bounce.Count > 0)
        {
            await qbit.Stop(nudge.Bounce, ct).ConfigureAwait(false);
            await Task.Delay(TimeSpan.FromSeconds(5), ct).ConfigureAwait(false);
            await qbit.Start(nudge.Bounce, ct).ConfigureAwait(false);
            Report($"restarted {nudge.Bounce.Count} stalled download(s): {string.Join(", ", nudge.BounceNames)}");
        }
    }

    /// <summary>Downloads that got no new data for a while, and what to do about them.</summary>
    internal static StallPlan DecideStalls(JsonArray torrents, Dictionary<string, StallTrack> tracks, DateTimeOffset now)
    {
        var plan = new StallPlan();
        var present = new HashSet<string>(StringComparer.Ordinal);
        foreach (var t in torrents)
        {
            var hash = ((string?)t?["hash"])?.ToLowerInvariant();
            if (hash is null)
            {
                continue;
            }

            present.Add(hash);
            var state = (string?)t!["state"] ?? string.Empty;
            var left = Num(t["amount_left"], -1);
            var forced = t["force_start"] is JsonValue f && f.TryGetValue<bool>(out var fb) && fb;
            // Only a download qBittorrent runs on its own: "stalledDL" or "downloading" (which
            // it shows while connected seeds refuse to send). Stopped, queued, checking,
            // forced, metadata and finished torrents are left alone, as are the 100 % ones the
            // recheck above deals with.
            if (state is not ("stalledDL" or "downloading") || forced || left <= 0 || FalselyComplete(t))
            {
                tracks.Remove(hash);
                continue;
            }

            if (!tracks.TryGetValue(hash, out var track) || track.Left != left)
            {
                // New, or new data since the last pass: the clock starts again.
                tracks[hash] = new StallTrack { Left = left, Since = now };
                continue;
            }

            var still = now - track.Since;
            var name = (string?)t["name"] ?? hash;
            if (still >= BounceAfter && (track.Bounced is null || now - track.Bounced >= BounceAgainAfter))
            {
                plan.Bounce.Add(hash);
                plan.BounceNames.Add(name);
                track.Bounced = now;
                track.Reannounced = now;
            }
            else if (still >= StallAfter && (track.Reannounced is null || now - track.Reannounced >= ReannounceAgainAfter))
            {
                plan.Reannounce.Add(hash);
                plan.ReannounceNames.Add(name);
                track.Reannounced = now;
            }
        }

        foreach (var gone in tracks.Keys.Where(h => !present.Contains(h)).ToList())
        {
            tracks.Remove(gone);
        }

        return plan;
    }

    private void Report(string text)
    {
        _log.LogWarning("Tortugarr: qBittorrent watchdog {Text}", text);
        var plugin = Plugin.Instance;
        if (plugin is null)
        {
            return;
        }

        plugin.Configuration.QbitWatchdogStatus = $"{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm}Z {text}";
        plugin.SaveConfiguration();
    }

    /// <summary>A torrent that claims all its data but never completed.</summary>
    internal static bool FalselyComplete(JsonNode? t)
    {
        if (t is null || !DownloadStates.Contains((string?)t["state"] ?? string.Empty))
        {
            return false;
        }

        if (Num(t["completion_on"], -1) > 0)
        {
            return false;
        }

        return Num(t["size"], 0) > 0 && (Num(t["progress"], 0) >= 1.0 || Num(t["amount_left"], 1) <= 0);
    }

    private static double Num(JsonNode? n, double fallback) => n is not JsonValue v ? fallback
        : v.TryGetValue<double>(out var d) ? d
        : v.TryGetValue<long>(out var l) ? l
        : v.TryGetValue<int>(out var i) ? i
        : fallback;

    /// <summary>What this pass does, from the torrent list and what earlier passes did.</summary>
    internal static WatchdogPlan Decide(JsonArray torrents, WatchdogState state, DateTimeOffset now, bool mayRestart)
    {
        var plan = new WatchdogPlan();
        var present = new HashSet<string>(StringComparer.Ordinal);
        var anyHashing = false;
        foreach (var t in torrents)
        {
            var hash = ((string?)t?["hash"])?.ToLowerInvariant();
            if (hash is null)
            {
                continue;
            }

            present.Add(hash);
            var torrentState = (string?)t!["state"] ?? string.Empty;
            anyHashing |= torrentState is "checkingDL" or "checkingUP";
            var name = (string?)t["name"] ?? hash;

            if (FalselyComplete(t))
            {
                // Seen on two passes in a row before acting: a torrent finishing right now
                // shows 100 % for a moment before its completion time is set.
                if (!state.FirstSeen.TryGetValue(hash, out var seen))
                {
                    state.FirstSeen[hash] = now;
                }
                else if (now - seen >= Every - TimeSpan.FromSeconds(30)
                    && (!state.Rechecked.TryGetValue(hash, out var at) || now - at >= RecheckAgainAfter))
                {
                    plan.Recheck.Add(hash);
                    plan.RecheckNames.Add(name);
                    state.Rechecked[hash] = now;
                }
                else if (state.Rechecked.TryGetValue(hash, out var at2) && now - at2 >= HangAfter)
                {
                    plan.HungNames.Add(name); // rechecked, and still claims 100 %
                }
            }
            else
            {
                state.FirstSeen.Remove(hash);
                if (torrentState == "checkingResumeData" && state.Rechecked.TryGetValue(hash, out var at) && now - at >= HangAfter)
                {
                    plan.HungNames.Add(name); // the recheck never started
                }
            }
        }

        foreach (var gone in state.FirstSeen.Keys.Concat(state.Rechecked.Keys).Where(h => !present.Contains(h)).ToList())
        {
            state.FirstSeen.Remove(gone);
            state.Rechecked.Remove(gone);
        }

        if (mayRestart && plan.HungNames.Count > 0 && !anyHashing
            && (state.LastRestart is null || now - state.LastRestart >= RestartAgainAfter))
        {
            plan.Restart = true;
            state.LastRestart = now;
        }

        return plan;
    }
}

/// <summary>What the watchdog remembers between passes.</summary>
internal sealed class WatchdogState
{
    public Dictionary<string, DateTimeOffset> FirstSeen { get; } = new(StringComparer.Ordinal);

    public Dictionary<string, DateTimeOffset> Rechecked { get; } = new(StringComparer.Ordinal);

    public DateTimeOffset? LastRestart { get; set; }

    public Dictionary<string, StallTrack> Stalls { get; } = new(StringComparer.Ordinal);
}

/// <summary>A download's bytes left when last seen moving, and the watchdog's nudges.</summary>
internal sealed class StallTrack
{
    public double Left { get; set; }

    public DateTimeOffset Since { get; set; }

    public DateTimeOffset? Reannounced { get; set; }

    public DateTimeOffset? Bounced { get; set; }
}

/// <summary>One pass's nudges for downloads that do not move.</summary>
internal sealed class StallPlan
{
    public List<string> Reannounce { get; } = new();

    public List<string> ReannounceNames { get; } = new();

    public List<string> Bounce { get; } = new();

    public List<string> BounceNames { get; } = new();
}

/// <summary>One pass's actions.</summary>
internal sealed class WatchdogPlan
{
    public List<string> Recheck { get; } = new();

    public List<string> RecheckNames { get; } = new();

    public List<string> HungNames { get; } = new();

    public bool Restart { get; set; }
}
