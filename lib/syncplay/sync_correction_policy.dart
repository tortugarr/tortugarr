/// Decides what SyncPlay drift correction should do about one measurement,
/// with no player or network dependencies so the timing rules can be exercised
/// on their own.
library;

import 'dart:math' as math;

enum SyncCorrectionAction { hold, defer, skip, speed, wait, giveUp }

class SyncCorrectionSettings {
  final bool useSkipToSync;

  /// Whether a rate nudge is an acceptable correction on this player. The
  /// manager clears it for players whose audio does not survive a rate change,
  /// whatever the user preference says: on those, [SyncCorrectionAction.wait]
  /// takes over the ahead case and small lateness is tolerated.
  final bool useSpeedToSync;
  final int minDelaySkipToSyncMs;
  final int minDelaySpeedToSyncMs;
  final int maxDelaySpeedToSyncMs;

  /// How long a nudge should take to close the gap, as in jellyfin-web. The
  /// rate needed is derived from it and capped at [SyncCorrectionPolicy
  /// .maxRateDeviation], so a large gap takes a longer nudge rather than an
  /// absurd rate.
  final int speedToSyncDurationMs;
  final int extraTimeOffsetMs;

  /// What a seek usually costs this player before it renders again. Seeds the
  /// seek-cost allowance before anything has been measured and paces how often
  /// corrective skips may be issued.
  final int typicalSeekLatencyMs;

  /// The longest a seek on this player may plausibly take. An attempt that has
  /// not settled within it is abandoned rather than waited on forever, and no
  /// learned allowance may exceed it.
  final int maxSeekLatencyMs;

  const SyncCorrectionSettings({
    required this.useSkipToSync,
    required this.useSpeedToSync,
    required this.minDelaySkipToSyncMs,
    required this.minDelaySpeedToSyncMs,
    required this.maxDelaySpeedToSyncMs,
    required this.speedToSyncDurationMs,
    this.extraTimeOffsetMs = 0,
    this.typicalSeekLatencyMs =
        SyncCorrectionPolicy.defaultTypicalSeekLatencyMs,
    this.maxSeekLatencyMs = SyncCorrectionPolicy.maxSeekLatencyAllowanceMs,
  });
}

class SyncCorrectionDecision {
  final SyncCorrectionAction action;
  /// Unclamped: the policy does not know the item duration.
  final int targetPositionMs;
  final double speed;
  final int speedDurationMs;
  /// How long to hold the player paused for [SyncCorrectionAction.wait].
  final int waitDurationMs;
  /// Positive means ahead of the group, zero when nothing was measurable.
  final int measuredDelayMs;

  const SyncCorrectionDecision._(
    this.action, {
    this.targetPositionMs = 0,
    this.speed = 1.0,
    this.speedDurationMs = 0,
    this.waitDurationMs = 0,
    this.measuredDelayMs = 0,
  });

  const SyncCorrectionDecision.defer() : this._(SyncCorrectionAction.defer);

  const SyncCorrectionDecision._hold(int delayMs)
      : this._(SyncCorrectionAction.hold, measuredDelayMs: delayMs);
}

/// One seek in flight: a skip we asked for, or one the group asked for. It is
/// open until the player is observed rendering at the new position, which is
/// what makes the seek's real cost measurable instead of assumed.
class _CorrectionAttempt {
  final int issuedAtMs;
  final int deadlineMs;
  final int targetMs;
  final int fromMs;

  /// How far off we were before this correction, so the result can be judged.
  /// Null for a group seek: there was no measurement to improve on.
  final int? preResidualMs;

  bool get isOwnSkip => preResidualMs != null;

  /// First sample seen at the new position with the pipeline not stalled.
  int? landedAtMs;

  /// Start of the window over which the player has been rendering real time
  /// since landing. Restarted whenever the position stops advancing, so a
  /// player that reports the target position before it has any frames for it
  /// is not credited with a landing it has not made.
  int? anchorMs;
  int anchorPositionMs = 0;

  bool settled = false;

  _CorrectionAttempt({
    required this.issuedAtMs,
    required this.deadlineMs,
    required this.targetMs,
    required this.fromMs,
    required this.preResidualMs,
  });

  void anchor(int nowMs, int positionMs) {
    anchorMs = nowMs;
    anchorPositionMs = positionMs;
  }

  /// Cost of this seek so far as it is known: rendering time if it has been
  /// seen, landing time otherwise, nothing if it never landed.
  int? get observedCostMs {
    final start = anchorMs ?? landedAtMs;
    if (start == null) return null;
    return start - issuedAtMs;
  }
}

class SyncCorrectionPolicy {
  // Backends sample position on a timer (250ms on Apple TV and media3), so
  // drift under this is quantisation noise and correcting on it just wobbles
  // the player every couple of seconds.
  static const int noiseFloorMs = 400;

  /// Default ceiling on what may be called seek cost. Backends that seek more
  /// slowly than this raise it through
  /// [SyncCorrectionSettings.maxSeekLatencyMs].
  static const int maxSeekLatencyAllowanceMs = 8000;
  static const int defaultTypicalSeekLatencyMs = 1500;

  /// Corrective skips allowed per item. Unlike a streak this is never cleared
  /// by a good measurement or by the group seeking, so no sequence of events
  /// can hand out an unlimited number of jumps.
  static const int maxSkipsPerItem = 10;

  /// Consecutive skips that failed to materially close the gap before we stop
  /// jumping at it.
  static const int maxFailedAttempts = 3;

  /// Being ahead by up to this much is answered by holding the player paused
  /// for exactly that long. It costs no seek and no rate change, which is why
  /// it is the correction of choice on players where either is disruptive,
  /// and it can never overshoot into a backwards jump.
  static const int maxWaitToSyncMs = 10000;

  /// A lead shorter than this is left alone rather than answered with a pause
  /// that would be more visible than the lead itself.
  static const int minWaitToSyncMs = 1000;

  /// The most a rate nudge may depart from 1x. Pitch correction copes with it
  /// and it is not disruptive to watch for the few seconds a nudge lasts.
  static const double maxRateDeviation = 0.2;

  /// A skip must close the gap to at least this fraction of what it was, or it
  /// did not work.
  static const double _improvementRatio = 0.6;

  /// How long past [SyncCorrectionSettings.maxSeekLatencyMs] an attempt may go
  /// unsettled before it is abandoned.
  static const int _settleGraceMs = 5000;

  /// A landed seek is somewhere near its target. The band covers a keyframe
  /// snap; anything further is judged by whether the position is closer to
  /// where the seek was going than to where it came from.
  static const int _landingToleranceMs = 1500;

  /// A player has settled when it has advanced roughly real time for at least
  /// this long since landing. Two 250ms samples are too few to tell rendering
  /// from position quantisation.
  static const int _settleWindowMs = 500;

  /// Rendering band for a settle window: absorbs 250ms position quantisation
  /// and a rate nudge, while rejecting a frozen position the player reports as
  /// playing.
  static const double _minSettleRate = 0.5;
  static const double _maxSettleRate = 1.5;

  /// Skips are aimed with the largest cost seen recently rather than the last
  /// one: undershooting costs another visible jump, while overshooting lands
  /// ahead and a wait takes that out exactly.
  static const int _allowanceDecayMs = 500;

  int? _seekLatencyAllowanceMs;
  int _skipsUsed = 0;
  int _failedAttempts = 0;
  int _skipCooldownUntilMs = 0;
  bool _gaveUp = false;

  /// Skips are suppressed but measurement and the gentler corrections continue,
  /// so the gap keeps being reported truthfully and can still close.
  bool _standDown = false;
  int _standDownResidualMs = 0;

  _CorrectionAttempt? _attempt;

  /// Allowance used to aim a skip. Unmeasured until a seek has been observed,
  /// in which case the backend's declared cost is the best guess: overshooting
  /// is cheap to fix, undershooting costs a second jump.
  int seekLatencyAllowanceFor(SyncCorrectionSettings settings) =>
      _seekLatencyAllowanceMs ?? settings.typicalSeekLatencyMs;

  /// The allowance learned from observed seeks, 0 until one has settled.
  int get seekLatencyAllowanceMs => _seekLatencyAllowanceMs ?? 0;
  int get skipsUsed => _skipsUsed;
  int get failedAttempts => _failedAttempts;
  bool get isStandingDown => _standDown;
  bool get hasGivenUp => _gaveUp;
  bool get hasOpenAttempt => _attempt != null;

  /// Feeds one player state sample. Meant to be called on every position
  /// update the backend pushes, so a seek's landing and its first rendered
  /// frames are timed at the backend's own resolution rather than the 2s
  /// correction tick. [evaluate] calls it as well, so a backend that pushes
  /// nothing still settles, just coarsely.
  void observe({
    required int nowMs,
    required int positionMs,
    required bool isPlaying,
    required bool isBuffering,
  }) {
    final attempt = _attempt;
    if (attempt == null || attempt.settled) return;
    // Scheduled for a sync point still in the future: nothing has happened.
    if (nowMs < attempt.issuedAtMs) return;

    if (isBuffering) {
      // A stall after an apparent landing means the player had the position
      // before it had the frames. Start over.
      attempt.landedAtMs = null;
      attempt.anchorMs = null;
      return;
    }

    if (attempt.landedAtMs == null) {
      final toTarget = (positionMs - attempt.targetMs).abs();
      final toOrigin = (positionMs - attempt.fromMs).abs();
      final landed = toTarget <= _landingToleranceMs || toTarget < toOrigin;
      if (!landed) return;
      attempt.landedAtMs = nowMs;
    }

    if (!isPlaying) {
      // Paused at the new position, as during the group's waiting handshake.
      // The landing is measured; rendering can only be seen once it resumes.
      attempt.anchorMs = null;
      return;
    }

    final anchor = attempt.anchorMs;
    if (anchor == null) {
      attempt.anchor(nowMs, positionMs);
      return;
    }
    final elapsed = nowMs - anchor;
    if (elapsed < _settleWindowMs) return;
    final rate = (positionMs - attempt.anchorPositionMs) / elapsed;
    if (rate >= _minSettleRate && rate <= _maxSettleRate) {
      attempt.settled = true;
    } else {
      // Not rendering yet: the position is parked at the target. Time the
      // window from here so the cost includes the wait for frames.
      attempt.anchor(nowMs, positionMs);
    }
  }

  SyncCorrectionDecision evaluate({
    required int nowMs,
    required int serverNowMs,
    required int currentPositionMs,
    required int lastSyncPositionMs,
    required int lastSyncTimeMs,
    required bool isBuffering,
    required bool isPlaying,
    required int clockJitterMs,
    required SyncCorrectionSettings settings,
  }) {
    observe(
      nowMs: nowMs,
      positionMs: currentPositionMs,
      isPlaying: isPlaying,
      isBuffering: isBuffering,
    );

    if (_gaveUp) {
      return const SyncCorrectionDecision._(SyncCorrectionAction.giveUp);
    }

    // A stalled or paused pipeline has a frozen position, so every sample reads
    // as far behind. Seeking on that measurement stalls the pipeline again,
    // which is the loop that leaves one client scrubbing in place while the
    // rest of the group plays on.
    if (isBuffering || !isPlaying) return const SyncCorrectionDecision.defer();

    final expectedMs = lastSyncPositionMs +
        (serverNowMs - lastSyncTimeMs) +
        settings.extraTimeOffsetMs;
    final delay = currentPositionMs - expectedMs;
    final absDelay = delay.abs();

    final attempt = _attempt;
    if (attempt != null) {
      if (!attempt.settled) {
        if (nowMs < attempt.deadlineMs) {
          return const SyncCorrectionDecision.defer();
        }
        // The player never came back. Nothing here is worth learning from, and
        // seeking at a client in this state is what pins it in place.
        _attempt = null;
        _noteFailure(delay);
        return SyncCorrectionDecision._hold(delay);
      }

      _attempt = null;
      _learnSeekLatency(attempt.observedCostMs, settings);

      final pre = attempt.preResidualMs;
      if (pre != null) {
        if (absDelay <= (pre.abs() * _improvementRatio).round()) {
          _failedAttempts = 0;
        } else {
          _noteFailure(delay);
        }
      }
      // A group seek leaves the client behind by exactly the seek's cost. That
      // used to be folded into the baseline, which redefined the late position
      // as in sync and left the client quietly behind for the rest of the
      // item. It is real lateness and is corrected like any other, by whatever
      // means this player has for a gap that size.
    }

    final floor = noiseFloorMs + (clockJitterMs ~/ 2);
    if (absDelay <= floor) return SyncCorrectionDecision._hold(delay);

    if (_standDown &&
        absDelay >
            math.max(
              3 * settings.minDelaySkipToSyncMs,
              _standDownResidualMs + 5000,
            )) {
      // Whatever we stood down over, this is worse. Worth one more try.
      _standDown = false;
      _failedAttempts = 0;
    }

    final canSkip = settings.useSkipToSync &&
        !_standDown &&
        nowMs >= _skipCooldownUntilMs;
    final canSpeed = settings.useSpeedToSync &&
        absDelay > settings.minDelaySpeedToSyncMs &&
        absDelay < settings.maxDelaySpeedToSyncMs;

    SyncCorrectionDecision skip() {
      if (_skipsUsed >= maxSkipsPerItem) {
        _gaveUp = true;
        return SyncCorrectionDecision._(
          SyncCorrectionAction.giveUp,
          measuredDelayMs: delay,
        );
      }
      _skipsUsed++;
      _skipCooldownUntilMs =
          nowMs + math.max(2000, settings.typicalSeekLatencyMs);
      final target = expectedMs + seekLatencyAllowanceFor(settings);
      _attempt = _CorrectionAttempt(
        issuedAtMs: nowMs,
        deadlineMs: nowMs + settings.maxSeekLatencyMs + _settleGraceMs,
        targetMs: target,
        fromMs: currentPositionMs,
        preResidualMs: delay,
      );
      return SyncCorrectionDecision._(
        SyncCorrectionAction.skip,
        targetPositionMs: target,
        measuredDelayMs: delay,
      );
    }

    if (delay < 0) {
      // Behind. Only a jump or a faster rate can make up time.
      if (canSkip && absDelay > settings.minDelaySkipToSyncMs) return skip();
      if (canSpeed) return _speed(delay, settings);
      return SyncCorrectionDecision._hold(delay);
    }

    // Ahead. A player that can change rate quietly slows down; any other
    // simply waits for the group, which is exact and needs no seek. A jump
    // backwards is the last resort, for a lead too long to sit through.
    if (canSpeed) return _speed(delay, settings);
    if (absDelay <= maxWaitToSyncMs) {
      if (absDelay < minWaitToSyncMs) {
        return SyncCorrectionDecision._hold(delay);
      }
      return SyncCorrectionDecision._(
        SyncCorrectionAction.wait,
        waitDurationMs: absDelay,
        measuredDelayMs: delay,
      );
    }
    if (canSkip) return skip();
    return SyncCorrectionDecision._hold(delay);
  }

  /// One nudge sized to close the whole gap, after which the next measurement
  /// should sit inside the noise floor. A fixed ±5% for a second closed 50ms
  /// per nudge, which is under the noise floor: it could never be seen to
  /// work, so it fired again every tick for as long as the gap lasted.
  SyncCorrectionDecision _speed(int delay, SyncCorrectionSettings settings) {
    final absDelay = delay.abs();
    final duration = math.max(1, settings.speedToSyncDurationMs);
    final deviation = math.min(maxRateDeviation, absDelay / duration);
    final speed = delay > 0 ? 1.0 - deviation : 1.0 + deviation;
    return SyncCorrectionDecision._(
      SyncCorrectionAction.speed,
      speed: speed,
      speedDurationMs: (absDelay / deviation).round(),
      measuredDelayMs: delay,
    );
  }

  void _noteFailure(int residualMs) {
    _failedAttempts++;
    if (_failedAttempts >= maxFailedAttempts) {
      _standDown = true;
      _standDownResidualMs = residualMs.abs();
    }
  }

  void _learnSeekLatency(int? observedCostMs, SyncCorrectionSettings settings) {
    if (observedCostMs == null) return;
    final current = _seekLatencyAllowanceMs;
    final decayed = current == null ? 0 : current - _allowanceDecayMs;
    final candidate = math.max(observedCostMs, decayed);
    _seekLatencyAllowanceMs = candidate.clamp(0, settings.maxSeekLatencyMs);
  }

  /// The group moved the playhead, so the old baseline and any convergence
  /// attempt against it are void. The learned seek latency belongs to the
  /// device and stream, so it survives, and a previous attempt that landed
  /// while paused (the group's waiting handshake) still teaches its cost.
  ///
  /// A stand-down is lifted here: it belongs to the stretch the group just
  /// left, and the new one may transcode or buffer differently. The per-item
  /// skip budget deliberately is not, so a group seeking repeatedly cannot
  /// re-mint an unlimited number of jumps.
  ///
  /// [nowMs] is when the seek reaches the player, [targetPositionMs] where it
  /// was sent and [fromPositionMs] where it was; landing is judged against
  /// both.
  void onSyncPointChanged(
    int nowMs, {
    required int targetPositionMs,
    required int fromPositionMs,
    required SyncCorrectionSettings settings,
  }) {
    _openSyncPoint(
      nowMs,
      targetPositionMs: targetPositionMs,
      fromPositionMs: fromPositionMs,
      settings: settings,
    );
  }

  /// The same as [onSyncPointChanged], for a sync point the player was
  /// already close enough to that nothing was sent to it: there is no landing
  /// to wait for, only the moment it renders again to observe. Waiting for a
  /// landing against a position the player has since played past would never
  /// end and would be scored as a failure.
  void onSyncPointResumed(
    int nowMs, {
    required int positionMs,
    required SyncCorrectionSettings settings,
  }) {
    _openSyncPoint(
      nowMs,
      targetPositionMs: positionMs,
      fromPositionMs: positionMs,
      settings: settings,
    ).landedAtMs = nowMs;
  }

  _CorrectionAttempt _openSyncPoint(
    int nowMs, {
    required int targetPositionMs,
    required int fromPositionMs,
    required SyncCorrectionSettings settings,
  }) {
    final previous = _attempt;
    if (previous != null) {
      _learnSeekLatency(previous.observedCostMs, settings);
    }
    _failedAttempts = 0;
    _standDown = false;
    _gaveUp = false;
    _skipCooldownUntilMs = 0;
    return _attempt = _CorrectionAttempt(
      issuedAtMs: nowMs,
      deadlineMs: nowMs + settings.maxSeekLatencyMs + _settleGraceMs,
      targetMs: targetPositionMs,
      fromMs: fromPositionMs,
      preResidualMs: null,
    );
  }

  /// The seek a skip asked for was close enough that the player never moved,
  /// so there is nothing to wait for and nothing to judge. Without this the
  /// attempt would sit open until it timed out and be scored as a failure.
  void onSkipDropped() {
    _attempt = null;
    _skipCooldownUntilMs = 0;
    if (_skipsUsed > 0) _skipsUsed--;
  }

  void reset() {
    _seekLatencyAllowanceMs = null;
    _skipsUsed = 0;
    _failedAttempts = 0;
    _skipCooldownUntilMs = 0;
    _gaveUp = false;
    _standDown = false;
    _standDownResidualMs = 0;
    _attempt = null;
  }
}
