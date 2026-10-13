import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/syncplay/sync_correction_policy.dart';

const _defaultSettings = SyncCorrectionSettings(
  useSkipToSync: true,
  useSpeedToSync: true,
  minDelaySkipToSyncMs: 2000,
  minDelaySpeedToSyncMs: 100,
  maxDelaySpeedToSyncMs: 5000,
  speedToSyncDurationMs: 1000,
);

/// A player that seeks as slowly as an Apple TV restarting a transcode and
/// whose audio does not survive a rate change, so the manager has cleared
/// speed-to-sync for it.
const _appleTvSettings = SyncCorrectionSettings(
  useSkipToSync: true,
  useSpeedToSync: false,
  minDelaySkipToSyncMs: 2000,
  minDelaySpeedToSyncMs: 100,
  maxDelaySpeedToSyncMs: 5000,
  speedToSyncDurationMs: 1000,
  typicalSeekLatencyMs: 4000,
  maxSeekLatencyMs: 20000,
);

/// The sampling cadence of the Apple TV and media3 position streams.
const _sampleMs = 250;

/// The manager's correction tick.
const _tickMs = 2000;

/// A client whose seeks take [seekLatencyMs] to render: after a seek the
/// position reads the target but freezes for that long, then advances with
/// the wall clock again.
///
/// [reportsBufferingWhileSeeking] false models a player that claims to be
/// playing while its clock is still frozen, which is what mpv looks like
/// across an in-buffer seek and what the Apple TV engine looks like if it
/// reports `.playing` before the seek has landed.
///
/// [acceptsSeeks] false models a seek the player silently ignored: the method
/// channel swallows the rejection, so nothing distinguishes it from success
/// except that the position never moves.
class _FakeClient {
  int seekLatencyMs;
  final bool reportsBufferingWhileSeeking;
  final bool acceptsSeeks;

  int nowMs = 0;
  int positionMs = 0;
  int stalledUntilMs = 0;
  int pausedUntilMs = 0;
  int baselineMs = 0;

  double _speed = 1.0;
  int _speedUntilMs = 0;

  _FakeClient({
    required this.seekLatencyMs,
    this.reportsBufferingWhileSeeking = true,
    this.acceptsSeeks = true,
  });

  bool get _isStalled => nowMs < stalledUntilMs;
  bool get isPaused => nowMs < pausedUntilMs;
  bool get isBuffering => reportsBufferingWhileSeeking && _isStalled;
  bool get isPlaying => !isBuffering && !isPaused;
  bool get nudgeActive => nowMs < _speedUntilMs;

  int get driftMs => positionMs - nowMs;

  void advance(int ms) {
    final end = nowMs + ms;
    final frozenUntil =
        stalledUntilMs > pausedUntilMs ? stalledUntilMs : pausedUntilMs;
    final resumedAt = frozenUntil > nowMs
        ? (frozenUntil < end ? frozenUntil : end)
        : nowMs;
    // Media advances at the nudged rate until the nudge expires, then at 1x.
    var at = resumedAt;
    while (at < end) {
      final nudged = _speedUntilMs > at;
      final segmentEnd = nudged && _speedUntilMs < end ? _speedUntilMs : end;
      positionMs += ((segmentEnd - at) * (nudged ? _speed : 1.0)).round();
      at = segmentEnd;
    }
    nowMs = end;
  }

  void stall(int ms) => stalledUntilMs = nowMs + ms;

  void pause(int ms) => pausedUntilMs = nowMs + ms;

  void applySpeed(double speed, int durationMs) {
    _speed = speed;
    _speedUntilMs = nowMs + durationMs;
  }

  void seekTo(int target) {
    if (!acceptsSeeks) return;
    positionMs = target;
    stalledUntilMs = nowMs + seekLatencyMs;
  }
}

/// Feeds the policy one sample, as the manager does for every position update.
void _observe(SyncCorrectionPolicy policy, _FakeClient client) {
  policy.observe(
    nowMs: client.nowMs,
    positionMs: client.positionMs,
    isPlaying: client.isPlaying,
    isBuffering: client.isBuffering,
  );
}

/// Advances [ms] of wall clock, sampling at the backend cadence throughout.
void _advance(SyncCorrectionPolicy policy, _FakeClient client, int ms) {
  var left = ms;
  while (left > 0) {
    final step = left < _sampleMs ? left : _sampleMs;
    client.advance(step);
    _observe(policy, client);
    left -= step;
  }
}

/// The group seeks to where it is now, so the target is the expected position.
void _groupSeek(
  SyncCorrectionPolicy policy,
  _FakeClient client, {
  SyncCorrectionSettings settings = _defaultSettings,
}) {
  final target = client.nowMs + client.baselineMs;
  final from = client.positionMs;
  client.seekTo(target);
  policy.onSyncPointChanged(
    client.nowMs,
    targetPositionMs: target,
    fromPositionMs: from,
    settings: settings,
  );
}

SyncCorrectionDecision _evaluate(
  SyncCorrectionPolicy policy,
  _FakeClient client, {
  SyncCorrectionSettings settings = _defaultSettings,
}) =>
    policy.evaluate(
      nowMs: client.nowMs,
      serverNowMs: client.nowMs,
      currentPositionMs: client.positionMs,
      lastSyncPositionMs: client.baselineMs,
      lastSyncTimeMs: 0,
      isBuffering: client.isBuffering,
      isPlaying: client.isPlaying,
      clockJitterMs: 0,
      settings: settings,
    );

/// Ticks at the manager's 2s cadence, applying decisions the way
/// `SyncPlayManager._performDriftCorrection` does. The manager does not
/// measure while a nudge or a wait it applied is still running, and neither
/// does this.
List<SyncCorrectionDecision> _run(
  SyncCorrectionPolicy policy,
  _FakeClient client, {
  required int ticks,
  SyncCorrectionSettings settings = _defaultSettings,
}) {
  final decisions = <SyncCorrectionDecision>[];
  for (var i = 0; i < ticks; i++) {
    _advance(policy, client, _tickMs);
    if (client.nudgeActive || client.isPaused) continue;
    final decision = _evaluate(policy, client, settings: settings);
    decisions.add(decision);
    switch (decision.action) {
      case SyncCorrectionAction.skip:
        client.seekTo(decision.targetPositionMs);
      case SyncCorrectionAction.speed:
        client.applySpeed(decision.speed, decision.speedDurationMs);
      case SyncCorrectionAction.wait:
        client.pause(decision.waitDurationMs);
      case SyncCorrectionAction.hold:
      case SyncCorrectionAction.defer:
      case SyncCorrectionAction.giveUp:
        break;
    }
  }
  return decisions;
}

int _countOf(List<SyncCorrectionDecision> decisions, SyncCorrectionAction a) =>
    decisions.where((d) => d.action == a).length;

void main() {
  group('drift correction convergence', () {
    test(
      'a slow-seeking client converges instead of skipping forever',
      () {
        // Every corrective skip used to land short by its own seek latency, so
        // the next check skipped again, permanently.
        final client = _FakeClient(seekLatencyMs: 3000)..stall(4000);
        final policy = SyncCorrectionPolicy();

        final decisions = _run(policy, client, ticks: 200);

        expect(
          _countOf(decisions, SyncCorrectionAction.skip),
          lessThanOrEqualTo(2),
          reason: 'each skip must fold in the latency it just measured',
        );
        expect(policy.hasGivenUp, isFalse);
        expect(policy.isStandingDown, isFalse);
        expect(
          client.driftMs.abs(),
          lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
          reason: 'the client should end up in sync, not just stop skipping',
        );
        expect(
          decisions.last.action,
          SyncCorrectionAction.hold,
          reason: 'a converged client keeps measuring but stops correcting',
        );
      },
    );

    test('seek cost is measured from player samples, not the correction tick',
        () {
      // Timed on the 2s tick, an instant seek read as a 2s cost and a 2.1s
      // seek as 4s. Aiming the next skip with that overshot by up to 2s every
      // time, which on a player that cannot nudge its rate was a jump
      // backwards.
      final client = _FakeClient(seekLatencyMs: 3000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      _run(policy, client, ticks: 10);

      expect(
        policy.seekLatencyAllowanceMs,
        inInclusiveRange(3000, 3000 + 2 * _sampleMs),
        reason: 'the cost is known to within a sample or two',
      );
    });

    test('stops jumping when it cannot converge, without hiding the gap', () {
      // This used to end in a give-up that disabled correction and left the
      // client sitting at whatever offset it happened to hold, reporting it as
      // zero. Standing down keeps the truth visible.
      final client = _FakeClient(seekLatencyMs: 14000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 400);

      expect(
        _countOf(decisions, SyncCorrectionAction.skip),
        lessThanOrEqualTo(SyncCorrectionPolicy.maxFailedAttempts),
      );
      expect(policy.isStandingDown, isTrue);
      expect(
        decisions.skip(decisions.length - 50).any(
              (d) => d.action == SyncCorrectionAction.skip,
            ),
        isFalse,
        reason: 'the visible jumping must stop',
      );
      expect(
        decisions.last.measuredDelayMs.abs(),
        greaterThan(SyncCorrectionPolicy.noiseFloorMs),
        reason: 'the real gap is still reported, never absorbed to zero',
      );
    });

    test('never corrects a client that is still buffering', () {
      final client = _FakeClient(seekLatencyMs: 500)..stall(60000);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 20);

      expect(
        decisions.every((d) => d.action == SyncCorrectionAction.defer),
        isTrue,
      );
      expect(policy.skipsUsed, 0);
    });

    test('never corrects a paused client', () {
      final policy = SyncCorrectionPolicy();
      final decision = policy.evaluate(
        nowMs: 30000,
        serverNowMs: 30000,
        currentPositionMs: 0,
        lastSyncPositionMs: 0,
        lastSyncTimeMs: 0,
        isBuffering: false,
        isPlaying: false,
        clockJitterMs: 0,
        settings: _defaultSettings,
      );
      expect(decision.action, SyncCorrectionAction.defer);
    });

    test('holds off re-measuring until a skip has settled', () {
      final client = _FakeClient(seekLatencyMs: 5000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 4);
      final firstSkip = decisions.indexWhere(
        (d) => d.action == SyncCorrectionAction.skip,
      );

      expect(firstSkip, isNonNegative);
      expect(
        decisions
            .skip(firstSkip + 1)
            .every((d) => d.action == SyncCorrectionAction.defer),
        isTrue,
        reason: 'measurements inside the settle window are not usable',
      );
    });

    test('a client that never settles is not corrected forever', () {
      // A player that stops rendering entirely must not be seeked at
      // repeatedly: that is what pins one client in place while the group
      // plays on.
      final client = _FakeClient(seekLatencyMs: 600000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 200);

      expect(
        _countOf(decisions, SyncCorrectionAction.skip),
        lessThanOrEqualTo(SyncCorrectionPolicy.maxFailedAttempts),
      );
      expect(
        policy.seekLatencyAllowanceMs,
        0,
        reason: 'an attempt that timed out teaches us nothing about seek cost',
      );
    });

    test('a skip aimed with a stale high cost is waited out, not jumped back',
        () {
      // Seek cost is not one number: a seek that restarts a transcode costs
      // seconds, the next one into a warm buffer almost nothing. A skip aimed
      // with the high cost then lands well ahead. Answering that with a jump
      // backwards, aimed with the same stale cost, lands ahead again, which
      // is the visible loop.
      final client = _FakeClient(seekLatencyMs: 6000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      // The first skip learns the cold cost.
      _run(policy, client, ticks: 8, settings: _appleTvSettings);
      expect(policy.seekLatencyAllowanceMs, greaterThanOrEqualTo(6000));

      // Fall behind again, but seeks are warm now.
      client.seekLatencyMs = 500;
      client.stall(5000);
      final decisions =
          _run(policy, client, ticks: 40, settings: _appleTvSettings);

      expect(
        _countOf(decisions, SyncCorrectionAction.skip),
        1,
        reason: 'the lead the overshoot leaves is never answered with a jump',
      );
      expect(_countOf(decisions, SyncCorrectionAction.wait), 1);
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
        reason: 'the wait is exact, so one is enough',
      );
    });
  });

  group('measurement noise', () {
    test('ignores drift within the position sampling resolution', () {
      // A sub-sample "drift" on a 250ms position stream is quantisation noise.
      final policy = SyncCorrectionPolicy();
      final decision = policy.evaluate(
        nowMs: 30000,
        serverNowMs: 30000,
        currentPositionMs: 29750,
        lastSyncPositionMs: 0,
        lastSyncTimeMs: 0,
        isBuffering: false,
        isPlaying: true,
        clockJitterMs: 0,
        settings: _defaultSettings,
      );

      expect(decision.action, SyncCorrectionAction.hold);
      expect(decision.measuredDelayMs, -250);
    });

    test('widens the dead band when the clock offset is jittery', () {
      final policy = SyncCorrectionPolicy();
      SyncCorrectionDecision evaluate(int jitter) => policy.evaluate(
            nowMs: 30000,
            serverNowMs: 30000,
            currentPositionMs: 29400,
            lastSyncPositionMs: 0,
            lastSyncTimeMs: 0,
            isBuffering: false,
            isPlaying: true,
            clockJitterMs: jitter,
            settings: _defaultSettings,
          );

      expect(evaluate(0).action, SyncCorrectionAction.speed);
      expect(evaluate(1200).action, SyncCorrectionAction.hold);
    });

    test('a position that is not advancing is never measured as drift', () {
      // The Apple TV samples position on a 250ms timer and can report playing
      // while the clock is still on the pre-seek frame. Trusting that sample
      // makes the seek's own cost look like drift and seeks at it again.
      final client = _FakeClient(
        seekLatencyMs: 30000,
        reportsBufferingWhileSeeking: false,
      );
      final policy = SyncCorrectionPolicy();
      _groupSeek(policy, client);

      final decisions = _run(policy, client, ticks: 6);

      expect(
        decisions.every((d) => d.action == SyncCorrectionAction.defer),
        isTrue,
        reason: 'a frozen position is not evidence of anything',
      );
      expect(policy.seekLatencyAllowanceMs, 0);
    });

    test('a seek with no buffering edge is still measured once it settles', () {
      // mpv never raises a buffering edge for an in-buffer seek, so the settle
      // test cannot rely on that flag alone.
      final client = _FakeClient(
        seekLatencyMs: 1200,
        reportsBufferingWhileSeeking: false,
      );
      final policy = SyncCorrectionPolicy();
      _groupSeek(policy, client);

      _run(policy, client, ticks: 10);

      expect(
        policy.seekLatencyAllowanceMs,
        inInclusiveRange(1200, 1200 + 3 * _sampleMs),
        reason: 'the cost is the time until the position started advancing',
      );
    });

    test(
        'a seek that lands while paused for the handshake still teaches its '
        'cost', () {
      // The group's waiting handshake holds every client paused at the target
      // until all have landed. Nothing renders, but the landing itself is
      // observable and is what the next skip needs to know.
      final client = _FakeClient(seekLatencyMs: 3000);
      final policy = SyncCorrectionPolicy();
      client.pause(60000);
      _groupSeek(policy, client);
      _advance(policy, client, 5000);

      // The Unpause that ends the handshake is a new sync point.
      policy.onSyncPointResumed(
        client.nowMs,
        positionMs: client.positionMs,
        settings: _defaultSettings,
      );

      expect(
        policy.seekLatencyAllowanceMs,
        inInclusiveRange(3000, 3000 + 2 * _sampleMs),
      );
    });
  });

  group('speed correction', () {
    SyncCorrectionDecision decisionFor(int positionMs) =>
        SyncCorrectionPolicy().evaluate(
          nowMs: 30000,
          serverNowMs: 30000,
          currentPositionMs: positionMs,
          lastSyncPositionMs: 0,
          lastSyncTimeMs: 0,
          isBuffering: false,
          isPlaying: true,
          clockJitterMs: 0,
          settings: _defaultSettings,
        );

    test('slows down when ahead of the group', () {
      final decision = decisionFor(31000);
      expect(decision.action, SyncCorrectionAction.speed);
      expect(decision.speed, lessThan(1.0));
    });

    test('speeds up when behind the group', () {
      final decision = decisionFor(29000);
      expect(decision.action, SyncCorrectionAction.speed);
      expect(decision.speed, greaterThan(1.0));
    });

    test('one nudge is sized to close the whole gap', () {
      // A fixed 5% for a second closed 50ms, under the noise floor, so it
      // could never be seen to work and fired again on every tick for as long
      // as the gap lasted. On mpv that is a tempo filter in and out every two
      // seconds; on AVPlayer it is an audible glitch each time.
      final small = decisionFor(29400);
      expect(small.speed, closeTo(1.2, 1e-9));
      expect(
        small.speed * small.speedDurationMs - small.speedDurationMs,
        closeTo(600, 1),
        reason: 'the media gained over the nudge is the gap',
      );

      // Anything past the skip threshold is a jump instead, so the longest
      // nudge is just under it.
      final large = decisionFor(28500);
      expect(
        large.speed,
        closeTo(1 + SyncCorrectionPolicy.maxRateDeviation, 1e-9),
        reason: 'a large gap takes a longer nudge, not a harsher rate',
      );
      expect(
        large.speed * large.speedDurationMs - large.speedDurationMs,
        closeTo(1500, 1),
      );
    });

    test('a nudge in flight is not fired again', () {
      final client = _FakeClient(seekLatencyMs: 0)..stall(1500);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 30);

      expect(
        _countOf(decisions, SyncCorrectionAction.speed),
        1,
        reason: 'one sized nudge closes the gap; the next check is inside the '
            'noise floor',
      );
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
      );
    });

    test('leaves the rate alone when speed-to-sync is off', () {
      final decision = SyncCorrectionPolicy().evaluate(
        nowMs: 30000,
        serverNowMs: 30000,
        currentPositionMs: 29000,
        lastSyncPositionMs: 0,
        lastSyncTimeMs: 0,
        isBuffering: false,
        isPlaying: true,
        clockJitterMs: 0,
        settings: _appleTvSettings,
      );
      expect(decision.action, SyncCorrectionAction.hold);
    });

    test('landing ahead of the group is corrected by rate, not another jump',
        () {
      // Skips are aimed high on purpose. Answering the overshoot with a second
      // jump would be the visible churn the whole design is avoiding.
      final client = _FakeClient(seekLatencyMs: 1000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      final decisions = _run(policy, client, ticks: 60);
      final firstSkip = decisions.indexWhere(
        (d) => d.action == SyncCorrectionAction.skip,
      );

      expect(firstSkip, isNonNegative);
      expect(
        decisions.skip(firstSkip + 1).any(
              (d) => d.action == SyncCorrectionAction.skip,
            ),
        isFalse,
        reason: 'the residual a skip leaves is not answered with another jump',
      );
      expect(
        decisions.skip(firstSkip + 1).any(
              (d) => d.action == SyncCorrectionAction.speed,
            ),
        isTrue,
        reason: 'it is taken out by the rate instead',
      );
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
      );
    });
  });

  group('waiting out a lead', () {
    SyncCorrectionDecision decisionFor(int positionMs) =>
        SyncCorrectionPolicy().evaluate(
          nowMs: 30000,
          serverNowMs: 30000,
          currentPositionMs: positionMs,
          lastSyncPositionMs: 0,
          lastSyncTimeMs: 0,
          isBuffering: false,
          isPlaying: true,
          clockJitterMs: 0,
          settings: _appleTvSettings,
        );

    test('a player that cannot nudge its rate waits for the group instead', () {
      // A pause needs no seek and no rate write, the two things that glitch
      // on the Apple TV engine, and it is exact where a nudge is approximate.
      final decision = decisionFor(33000);
      expect(decision.action, SyncCorrectionAction.wait);
      expect(decision.waitDurationMs, 3000);
    });

    test('a short lead is left alone rather than stalled over', () {
      final decision =
          decisionFor(30000 + SyncCorrectionPolicy.minWaitToSyncMs - 100);
      expect(decision.action, SyncCorrectionAction.hold);
      expect(decision.measuredDelayMs, greaterThan(0));
    });

    test('a lead too long to sit through is jumped back instead', () {
      final decision =
          decisionFor(30000 + SyncCorrectionPolicy.maxWaitToSyncMs + 2000);
      expect(decision.action, SyncCorrectionAction.skip);
    });

    test('a wait lands the client on the group exactly', () {
      final client = _FakeClient(seekLatencyMs: 0);
      final policy = SyncCorrectionPolicy();
      client.positionMs = 3000;

      final decisions =
          _run(policy, client, ticks: 10, settings: _appleTvSettings);

      expect(_countOf(decisions, SyncCorrectionAction.wait), 1);
      expect(_countOf(decisions, SyncCorrectionAction.skip), 0);
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
      );
      expect(decisions.last.action, SyncCorrectionAction.hold);
    });
  });

  group('group seeks', () {
    test('a sync point with no seek behind it settles on the spot', () {
      // The server re-sends the sync point it is on when it hears a Ready
      // mid-play, and the resume for it finds the player already inside the
      // seek tolerance. Judged as a landing against a position the player has
      // since played past, that attempt would never settle and would time
      // out as a failure.
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 3000);
      _advance(policy, client, 10000);
      policy.onSyncPointResumed(
        client.nowMs,
        positionMs: client.positionMs,
        settings: _defaultSettings,
      );

      final decisions = _run(policy, client, ticks: 3);

      expect(policy.hasOpenAttempt, isFalse);
      expect(policy.failedAttempts, 0);
      expect(decisions.last.action, SyncCorrectionAction.hold);
    });

    test('a group seek is given time to land before anything is measured', () {
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 3000);
      _groupSeek(policy, client);

      expect(_run(policy, client, ticks: 1).single.action,
          SyncCorrectionAction.defer);
    });

    test('a group seek residual is corrected, never absorbed into the baseline',
        () {
      // The seek's own cost used to be folded into the baseline, which
      // redefined the client's late position as in sync: it reported zero
      // drift while sitting behind the group for the rest of the item.
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 1200);
      _groupSeek(policy, client);

      final decisions = _run(policy, client, ticks: 30);

      expect(_countOf(decisions, SyncCorrectionAction.skip), 0);
      expect(
        _countOf(decisions, SyncCorrectionAction.speed),
        1,
        reason: 'a residual under the skip threshold is one sized nudge',
      );
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
        reason: 'the client must end up where the group actually is',
      );
      expect(
        policy.seekLatencyAllowanceMs,
        greaterThanOrEqualTo(1200),
        reason: 'the residual is the seek latency, worth learning',
      );
    });

    test(
        'a small residual on a player without rate nudges is tolerated, not '
        'hidden', () {
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 1200);
      _groupSeek(policy, client, settings: _appleTvSettings);

      final decisions =
          _run(policy, client, ticks: 30, settings: _appleTvSettings);

      expect(_countOf(decisions, SyncCorrectionAction.skip), 0);
      expect(_countOf(decisions, SyncCorrectionAction.wait), 0);
      expect(
        decisions.last.measuredDelayMs,
        inInclusiveRange(-1200 - _sampleMs, -1200 + _sampleMs),
        reason: 'the gap is still reported truthfully so later drift on top '
            'of it is corrected against the group, not against this offset',
      );
    });

    test(
      'a group seek residual too large to ignore is corrected, not absorbed',
      () {
        // The residual used to be folded into the baseline for anything up to
        // eight seconds. It left the client seven seconds behind the group for
        // the rest of the item while reporting zero drift the whole time.
        final policy = SyncCorrectionPolicy();
        final client = _FakeClient(seekLatencyMs: 7000);
        _groupSeek(policy, client);

        final decisions = _run(policy, client, ticks: 60);

        expect(_countOf(decisions, SyncCorrectionAction.skip), 1);
        expect(
          client.driftMs.abs(),
          lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
          reason: 'the client must end up where the group actually is',
        );
      },
    );

    test('real drift after a group seek is still corrected', () {
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 1200);
      _groupSeek(policy, client);
      _run(policy, client, ticks: 10);

      // A stall well after the seek is genuine drift, not seek cost.
      client.stall(5000);
      final decisions = _run(policy, client, ticks: 12);

      expect(
        _countOf(decisions, SyncCorrectionAction.skip) +
            _countOf(decisions, SyncCorrectionAction.speed),
        greaterThan(0),
      );
    });

    test('an apple tv seek cost past the desktop cap still converges', () {
      // Twelve seconds is past the 8s ceiling a desktop profile allows, so
      // every skip used to land short by the difference, forever. It is also
      // what a transcoding client can look like.
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 12000);
      _groupSeek(policy, client, settings: _appleTvSettings);

      final decisions = _run(
        policy,
        client,
        ticks: 120,
        settings: _appleTvSettings,
      );

      expect(policy.hasGivenUp, isFalse);
      expect(policy.isStandingDown, isFalse);
      expect(
        _countOf(decisions, SyncCorrectionAction.skip),
        1,
        reason: 'the cost learned from the group seek aims the one skip',
      );
      expect(
        policy.seekLatencyAllowanceMs,
        greaterThanOrEqualTo(12000),
        reason: 'the profile must allow an allowance as large as the real cost',
      );
      expect(
        client.driftMs.abs(),
        lessThanOrEqualTo(SyncCorrectionPolicy.noiseFloorMs),
      );
    });

    test('a seek the player silently ignored is not treated as progress', () {
      // The method channel swallows a rejected seek, so the only evidence is
      // that the position never moved.
      final policy = SyncCorrectionPolicy();
      final client = _FakeClient(seekLatencyMs: 0, acceptsSeeks: false)
        ..stall(6000);

      final decisions = _run(policy, client, ticks: 200);

      expect(
        _countOf(decisions, SyncCorrectionAction.skip),
        lessThanOrEqualTo(SyncCorrectionPolicy.maxFailedAttempts),
        reason: 'a seek that changes nothing must not be retried forever',
      );
      expect(policy.isStandingDown, isTrue);
    });
  });

  group('lifecycle', () {
    test('a new sync point clears the failure ledger but keeps the latency',
        () {
      final client = _FakeClient(seekLatencyMs: 3000)..stall(4000);
      final policy = SyncCorrectionPolicy();
      _run(policy, client, ticks: 10);

      expect(policy.seekLatencyAllowanceMs, greaterThan(0));
      final learned = policy.seekLatencyAllowanceMs;

      _groupSeek(policy, client);

      expect(policy.failedAttempts, 0);
      expect(
        policy.seekLatencyAllowanceMs,
        learned,
        reason: 'seek latency is a property of the device and stream',
      );
    });

    test("the first skip is aimed with the backend's declared cost", () {
      // Overshooting is taken out by a wait or a slow-down; undershooting
      // costs a second visible jump. So before anything has been measured the
      // backend's own figure is the aim, not zero.
      final client = _FakeClient(seekLatencyMs: 4000)..stall(5000);
      final policy = SyncCorrectionPolicy();

      final decisions =
          _run(policy, client, ticks: 3, settings: _appleTvSettings);
      final skip = decisions.firstWhere(
        (d) => d.action == SyncCorrectionAction.skip,
      );

      expect(
        skip.targetPositionMs - client.nowMs,
        _appleTvSettings.typicalSeekLatencyMs,
      );
    });

    test('a new item clears a stand-down', () {
      final client = _FakeClient(seekLatencyMs: 14000)..stall(4000);
      final policy = SyncCorrectionPolicy();
      _run(policy, client, ticks: 400);
      expect(policy.isStandingDown, isTrue);

      policy.reset();

      expect(policy.isStandingDown, isFalse);
      expect(policy.hasGivenUp, isFalse);
      expect(policy.seekLatencyAllowanceMs, 0);
      expect(policy.skipsUsed, 0);
    });

    test('a stand-down keeps reporting the gap it stood down over', () {
      final client = _FakeClient(seekLatencyMs: 14000)..stall(4000);
      final policy = SyncCorrectionPolicy();
      _run(policy, client, ticks: 400);

      // The same gap it stood down over must still be reported, and must not
      // start the jumping again. Only a materially worse one re-arms.
      final standing = _run(policy, client, ticks: 1).single;

      expect(
        standing.measuredDelayMs.abs(),
        greaterThan(SyncCorrectionPolicy.noiseFloorMs),
        reason: 'the gap is still measured, never absorbed to zero',
      );
      expect(
        standing.action,
        isNot(SyncCorrectionAction.skip),
        reason: 'standing down suppresses the jumping, not the measuring',
      );
    });

    test('a group seek lifts a stand-down', () {
      final client = _FakeClient(seekLatencyMs: 14000)..stall(4000);
      final policy = SyncCorrectionPolicy();
      _run(policy, client, ticks: 400);
      expect(policy.isStandingDown, isTrue);

      _groupSeek(policy, client);

      expect(policy.isStandingDown, isFalse);
      expect(policy.failedAttempts, 0);
    });

    test('a group seek revives correction but not an unlimited skip budget',
        () {
      // The streak used to be cleared by every sync point, so a group that
      // seeks now and then handed out an unbounded number of jumps.
      final client = _FakeClient(seekLatencyMs: 14000)..stall(4000);
      final policy = SyncCorrectionPolicy();

      var skips = 0;
      for (var round = 0; round < 20; round++) {
        _groupSeek(policy, client);
        skips += _countOf(
          _run(policy, client, ticks: 20),
          SyncCorrectionAction.skip,
        );
      }

      expect(
        skips,
        lessThanOrEqualTo(SyncCorrectionPolicy.maxSkipsPerItem),
        reason: 'the per-item budget is the one thing a sync point cannot '
            'clear, so no sequence of group seeks can jump forever',
      );
      expect(policy.hasGivenUp, isTrue);
    });

    test('a dropped seek is not counted as a correction attempt', () {
      // A target inside the manager's seek tolerance never reaches the player,
      // so there is nothing to wait for and nothing to judge.
      final client = _FakeClient(seekLatencyMs: 3000)..stall(4000);
      final policy = SyncCorrectionPolicy();
      _run(policy, client, ticks: 2);
      final usedBefore = policy.skipsUsed;

      policy.onSkipDropped();

      expect(policy.skipsUsed, usedBefore - 1);
      expect(policy.failedAttempts, 0);
    });
  });
}
