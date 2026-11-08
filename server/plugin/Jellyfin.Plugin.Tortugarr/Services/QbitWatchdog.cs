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
/// send to it. Asking the trackers for fresh peers got it going. After 1 minute without new
/// data the watchdog does that; after 3 it stops and starts the torrent so every connection
/// is made fresh. After 3 hours with nothing new it gives up: a Radarr/Sonarr download is
/// swapped for the best-seeded release of about the same size, an XXX download is deleted
/// with its partial files, and the admin gets a popup in the app (activity log type
/// "TortugarrStall"). Torrents the user stopped, forced, queued or finished are never touched.
/// </summary>
public sealed class QbitWatchdog : Microsoft.Extensions.Hosting.IHostedService
{
    internal static readonly TimeSpan Every = TimeSpan.FromMinutes(3);
    internal static readonly TimeSpan HangAfter = TimeSpan.FromMinutes(10);
    internal static readonly TimeSpan RecheckAgainAfter = TimeSpan.FromMinutes(30);
    internal static readonly TimeSpan RestartAgainAfter = TimeSpan.FromMinutes(30);
    // Stalls are checked on their own quick loop: waiting minutes on a torrent that sits
    // still felt like forever (user, 2026-11-07).
    internal static readonly TimeSpan StallEvery = TimeSpan.FromSeconds(30);
    internal static readonly TimeSpan StallAfter = TimeSpan.FromMinutes(1);
    internal static readonly TimeSpan ReannounceAgainAfter = TimeSpan.FromMinutes(2);
    internal static readonly TimeSpan BounceAfter = TimeSpan.FromMinutes(3);
    internal static readonly TimeSpan BounceAgainAfter = TimeSpan.FromMinutes(15);

    // When nothing helped: Radarr/Sonarr downloads are swapped for another release, XXX ones
    // deleted with their partial files, and the admin gets a popup (user, 2026-11-07).
    internal static readonly TimeSpan GiveUpAfter = TimeSpan.FromHours(3);

    // A magnet that never gets its metadata has nobody sharing it: given up much sooner.
    internal static readonly TimeSpan MetadataGiveUpAfter = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan QuietAfterRestart = TimeSpan.FromMinutes(2);

    // A fake must look fake on two passes before it goes: Radarr/Sonarr may still be busy.
    internal static readonly TimeSpan FakeConfirmAfter = Every - TimeSpan.FromSeconds(30);

    private static readonly HashSet<string> DownloadStates = new(StringComparer.Ordinal)
    {
        "downloading", "stalledDL", "forcedDL", "queuedDL", "metaDL", "forcedMetaDL",
    };

    private readonly TortugarrService _svc;
    private readonly ILogger<QbitWatchdog> _log;
    private readonly AdminNotice _notice;
    private readonly WatchdogState _state = new();
    private CancellationTokenSource? _stop;
    private long _restartedAtTicks;

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
        _ = Task.Run(async () =>
        {
            await Task.Delay(TimeSpan.FromMinutes(2), token).ConfigureAwait(false);
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await ScreenNewAsync(token).ConfigureAwait(false);
                    await NudgeAsync(token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
                catch (Exception e)
                {
                    _log.LogDebug(e, "Tortugarr: stall pass skipped");
                }

                await Task.Delay(StallEvery, token).ConfigureAwait(false);
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

        await SweepFakesAsync(ct).ConfigureAwait(false);
        await SweepEarlyAsync(ct).ConfigureAwait(false);

        if (plan.Restart)
        {
            Interlocked.Exchange(ref _restartedAtTicks, DateTimeOffset.UtcNow.UtcTicks);
            await qbit.Shutdown(ct).ConfigureAwait(false);
            Report($"closed qBittorrent for a restart: the recheck of {string.Join(", ", plan.HungNames)} hung");
            await _notice.PostAsync("Qbit", "qBittorrent restarted",
                $"The file check of {string.Join(", ", plan.HungNames)} hung; Tortugarr closed qBittorrent so it starts fresh.",
                LogLevel.Warning).ConfigureAwait(false);
        }
    }

    /// <summary>
    /// Finished Radarr/Sonarr downloads with no video in them (an .exe, a .zip) never import
    /// and would sit in qBittorrent forever. They are removed with their files, the release is
    /// blocklisted and Radarr/Sonarr search for another one (user, 2026-11-07: only XXX may
    /// stay in qBittorrent).
    /// </summary>
    private async Task SweepFakesAsync(CancellationToken ct)
    {
        var found = await _svc.ListFakes(ct).ConfigureAwait(false);
        foreach (var fake in DecideFakes(found, _state.Fakes, DateTimeOffset.UtcNow))
        {
            try
            {
                await _svc.RemoveFake(fake, ct).ConfigureAwait(false);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                _log.LogWarning(e, "Tortugarr: could not remove the fake download {Title}", fake.Title);
                continue;
            }

            Report($"removed fake download {fake.Title} ({fake.Reason}); blocklisted, {fake.Arr} searches again");
            await _notice.PostAsync("Stall", $"Fake download removed: {fake.Title}",
                $"It held no video ({fake.Reason}). Tortugarr removed it from qBittorrent with its files, blocklisted the release, and {fake.Arr} is looking for another one.",
                LogLevel.Warning).ConfigureAwait(false);
        }
    }

    /// <summary>Radarr grabs of a release posted before the film was out at home: removed and blocklisted.</summary>
    private async Task SweepEarlyAsync(CancellationToken ct)
    {
        List<EarlyGrab> early;
        try
        {
            early = await _svc.ListEarlyGrabs(_state.EarlyChecked, ct).ConfigureAwait(false);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            _log.LogDebug(e, "Tortugarr: early-grab check skipped");
            return;
        }

        foreach (var g in early)
        {
            try
            {
                await _svc.RejectEarlyGrab(g, ct).ConfigureAwait(false);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                _log.LogWarning(e, "Tortugarr: could not remove the early grab {Title}", g.Title);
                continue;
            }

            Report($"removed {g.Title}: posted {g.Published:yyyy-MM-dd}, before {g.Movie} was out at home ({g.HomeRelease:yyyy-MM-dd}); blocklisted");
            await _notice.PostAsync("Stall", $"Wrong release removed: {g.Title}",
                $"It was posted {g.Published:d MMM yyyy}, before {g.Movie} came out digitally ({g.HomeRelease:d MMM yyyy}), so it is almost surely another film of the same name or a fake. Tortugarr removed and blocklisted it; Radarr keeps watching for a real release.",
                LogLevel.Warning).ConfigureAwait(false);
        }
    }

    /// <summary>Fakes seen on an earlier pass too; forgets the ones that are gone.</summary>
    internal static List<FakeDownload> DecideFakes(List<FakeDownload> found, Dictionary<string, DateTimeOffset> seen, DateTimeOffset now)
    {
        var act = new List<FakeDownload>();
        var present = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in found)
        {
            present.Add(f.DownloadId);
            if (!seen.TryGetValue(f.DownloadId, out var first))
            {
                seen[f.DownloadId] = now;
            }
            else if (now - first >= FakeConfirmAfter)
            {
                act.Add(f);
            }
        }

        foreach (var gone in seen.Keys.Where(k => !present.Contains(k)).ToList())
        {
            seen.Remove(gone);
        }

        foreach (var f in act)
        {
            seen.Remove(f.DownloadId);
        }

        return act;
    }

    /// <summary>
    /// Runs the video check on every torrent once it has its file list, whoever added it:
    /// Radarr/Sonarr RSS grabs never pass the app's check. A torrent without a video is removed
    /// and blocklisted within a minute of getting its metadata.
    /// </summary>
    private async Task ScreenNewAsync(CancellationToken ct)
    {
        var cfg = Plugin.Instance?.Configuration;
        if (cfg is null || !cfg.QbitWatchdogEnabled || cfg.DownloadClientType != "qbittorrent" || string.IsNullOrWhiteSpace(cfg.DownloadClientUrl))
        {
            return;
        }

        var qbit = _svc.Qbit;
        var torrents = await qbit.ListAll(ct).ConfigureAwait(false);
        var present = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var t in torrents)
        {
            var hash = (string?)t?["hash"];
            var category = (string?)t?["category"];
            if (hash is null)
            {
                continue;
            }

            present.Add(hash);
            if (_state.Screened.Contains(hash) || !_svc.IsScreenedCategory(category))
            {
                continue;
            }

            var (hasVideo, files) = await _svc.ScreenDownload(qbit, hash, category!, ct).ConfigureAwait(false);
            if (hasVideo is null)
            {
                continue; // no file list yet; next pass
            }

            _state.Screened.Add(hash);
            if (hasVideo == false)
            {
                var name = (string?)t!["name"] ?? hash;
                var what = string.Join(", ", files!.Take(3).Select(f => Path.GetFileName(f.Name)));
                Report($"removed {name}: no video in it ({what}); blocklisted");
                await _notice.PostAsync("Stall", $"Fake download removed: {name}",
                    $"It held no video ({what}). Tortugarr removed it before it downloaded and blocklisted the release; Radarr/Sonarr look for another one.",
                    LogLevel.Warning).ConfigureAwait(false);
            }
        }

        _state.Screened.RemoveWhere(h => !present.Contains(h));
    }

    private async Task NudgeAsync(CancellationToken ct)
    {
        var cfg = Plugin.Instance?.Configuration;
        if (cfg is null || !cfg.QbitWatchdogEnabled || !cfg.QbitStallNudge || cfg.DownloadClientType != "qbittorrent" || string.IsNullOrWhiteSpace(cfg.DownloadClientUrl))
        {
            return;
        }

        // The watchdog just closed qBittorrent: every connection starts fresh anyway.
        var restarted = new DateTimeOffset(Interlocked.Read(ref _restartedAtTicks), TimeSpan.Zero);
        if (DateTimeOffset.UtcNow - restarted < QuietAfterRestart)
        {
            return;
        }

        var qbit = _svc.Qbit;
        var torrents = await qbit.ListAll(ct).ConfigureAwait(false);
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

        foreach (var dead in nudge.GiveUp)
        {
            await GiveUpAsync(dead, ct).ConfigureAwait(false);
        }
    }

    private async Task GiveUpAsync(StalledDownload dead, CancellationToken ct)
    {
        var hours = (int)GiveUpAfter.TotalHours;
        string outcome;
        try
        {
            outcome = await _svc.GiveUpStalled(dead, ct).ConfigureAwait(false);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            _log.LogWarning(e, "Tortugarr: could not give up the stalled download {Name}", dead.Name);
            outcome = $"Tortugarr could not remove it ({e.Message}); it is still in qBittorrent.";
        }

        Report($"gave up {dead.Name} at {dead.Progress * 100:0.#} % after {hours} h without new data: {outcome}");
        await _notice.PostAsync("Stall", $"Download given up: {dead.Name}",
            $"Stuck at {dead.Progress * 100:0.#} % for {hours} hours although Tortugarr asked for new peers and restarted it. {outcome}",
            LogLevel.Warning).ConfigureAwait(false);
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
            // "metaDL": a magnet still waiting for its metadata (no peer has answered at all).
            var meta = state == "metaDL";
            if (meta)
            {
                left = -1; // unknown until the metadata arrives; any change then restarts the clock
            }

            if (!(meta || state is "stalledDL" or "downloading") || forced || (!meta && (left <= 0 || FalselyComplete(t))))
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
            if (still >= (meta ? MetadataGiveUpAfter : GiveUpAfter))
            {
                if (!track.GaveUp)
                {
                    plan.GiveUp.Add(new StalledDownload(hash, name, (string?)t["category"] ?? string.Empty, Num(t["size"], 0), Num(t["progress"], 0)));
                    track.GaveUp = true;
                }

                continue;
            }

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
    public HashSet<string> EarlyChecked { get; } = new(StringComparer.OrdinalIgnoreCase);

    public HashSet<string> Screened { get; } = new(StringComparer.OrdinalIgnoreCase);

    public Dictionary<string, DateTimeOffset> Fakes { get; } = new(StringComparer.OrdinalIgnoreCase);

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

    public bool GaveUp { get; set; }
}

/// <summary>A download the watchdog gives up on.</summary>
internal sealed record StalledDownload(string Hash, string Name, string Category, double Size, double Progress);

/// <summary>One pass's nudges for downloads that do not move.</summary>
internal sealed class StallPlan
{
    public List<string> Reannounce { get; } = new();

    public List<string> ReannounceNames { get; } = new();

    public List<string> Bounce { get; } = new();

    public List<string> BounceNames { get; } = new();

    public List<StalledDownload> GiveUp { get; } = new();
}

/// <summary>One pass's actions.</summary>
internal sealed class WatchdogPlan
{
    public List<string> Recheck { get; } = new();

    public List<string> RecheckNames { get; } = new();

    public List<string> HungNames { get; } = new();

    public bool Restart { get; set; }
}

/// <summary>A finished Radarr/Sonarr download that will never import: it holds no video.</summary>
internal sealed record FakeDownload(string Arr, int QueueId, string DownloadId, string Title, string Reason);

/// <summary>A Radarr download whose release was posted before the film came out at home.</summary>
internal sealed record EarlyGrab(int QueueId, string DownloadId, string Title, string Movie, DateTimeOffset Published, DateTimeOffset HomeRelease);
