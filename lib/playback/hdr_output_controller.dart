import 'package:flutter/foundation.dart';

import 'hdr_video_window.dart';

/// Whether native HDR output is running and, if not, why - for the playback
/// info sheet.
enum HdrOutputStatus {
  /// Running: HDR is reaching the display untouched.
  active,
  disabledByPreference,
  displayNotInHdrMode,
  contentIsSdr,

  /// The window could not be created, or mpv would not take it. Sticky for
  /// the session, and the texture path carries on.
  failed;

  bool get isActive => this == active;

  /// Whether the answer came from one of the two expensive checks and may
  /// have been given too early, so a later fact is allowed to reopen it.
  ///
  /// Both are questions whose true answer can arrive after they were asked:
  /// mpv reports what it decoded only once the file is loaded, and a big
  /// remux over the network can take longer than any bounded wait; the
  /// display is switched by the auto-HDR preference asynchronously. The
  /// preference and a failure, by contrast, are settled for the session.
  bool get isRevisitable => this == contentIsSdr || this == displayNotInHdrMode;
}

/// Decides whether mpv gets its own window, and owns that window's lifetime.
///
/// The decision is made once per presenting screen and then sticks. `Player`
/// and `VideoController` are built once in the `MediaKitPlayerBackend` factory
/// and registered as a startup singleton, so there is no clean way to swap
/// paths per item — and there is no need to. Once engaged, SDR content in the
/// native window is not a regression: mpv renders it, and with `gpu-next`
/// renders it better than the texture path does.
class HdrOutputController {
  /// [window] is injectable so the decision can be tested without a platform
  /// channel - every path through [maybeEngage] past the display gate touches
  /// it, and those are the paths worth pinning down.
  HdrOutputController({HdrVideoWindow? window})
    : window = window ?? HdrVideoWindow();

  final HdrVideoWindow window;

  /// What is actually going to the display while [HdrOutputStatus.active].
  ///
  /// Always HDR10: DXGI carries only static HDR10 metadata, so there is no
  /// HDR10+ or Dolby Vision passthrough on Windows for a normal application.
  /// libplacebo applies the dynamic metadata or the RPU and folds the result
  /// into HDR10, which is the best available - not a shortcut.
  static const String activeOutputFormat = 'HDR10 (PQ, BT.2020)';

  /// The single source of truth for engagement; [isEngaged] and [hasFailed]
  /// are views of it.
  ///
  /// A notifier rather than a plain field because engagement finishes
  /// asynchronously at the tail of `play()`, long after the player screen last
  /// built. Without a signal the swap from the texture surface to the native
  /// window would wait for some unrelated setState to happen along, and until
  /// it did mpv would be drawing into a window nothing had claimed - so still
  /// hidden.
  final ValueNotifier<HdrOutputStatus> status = ValueNotifier(
    HdrOutputStatus.contentIsSdr,
  );

  bool get isEngaged => status.value.isActive;

  /// Whether a previous attempt failed. Sticky, so a broken configuration is
  /// not retried on every item.
  bool get hasFailed => status.value == HdrOutputStatus.failed;

  /// Whoever is currently presenting, or null.
  ///
  /// The backend is a process-wide singleton shared with Live TV and the mini
  /// player, which render media_kit's texture and know nothing about the
  /// native window - engaging under them would swap mpv onto a window nothing
  /// ever shows and leave a black picture. Only the video player screen sets
  /// this, and engagement is refused without it.
  ///
  /// Held by identity, for the same reason [HdrVideoWindow] holds its own: the
  /// player screen is rebuilt on route changes and the incoming state mounts
  /// before the outgoing one disposes, so a departing screen must not stand
  /// down a session its successor has already taken over.
  Object? presenter;

  bool get presenterActive => presenter != null;

  /// One decision at a time. The sticky flags are only written after several
  /// awaits, so without this two overlapping `play()` calls could both pass
  /// the gates and run the mpv handover concurrently against the same window.
  bool _deciding = false;

  /// Back to the undecided state, for when the presenting screen goes away:
  /// the next playback decides afresh instead of inheriting a sticky
  /// engagement nothing can present any more.
  void reset() {
    status.value = HdrOutputStatus.contentIsSdr;
  }

  /// Decides and, if the answer is yes, creates the window.
  ///
  /// Returns the HWND to hand mpv as `wid`, or null to stay on the texture
  /// path. Every cheap gate - engaged, failed, no presenter, preference off -
  /// is answered before either callback runs.
  ///
  /// A "no" from either expensive check is not sticky (see
  /// [HdrOutputStatus.isRevisitable]): calling again decides afresh, which is
  /// how the backend reopens the question once mpv reports HDR params that
  /// were not there yet when the first decision was made.
  ///
  /// [isHdrContent] and [displayInHdrMode] are callbacks rather than values
  /// because both are expensive and neither is needed unless everything ahead
  /// of it passed. Waiting for mpv's video-params costs up to two seconds on
  /// an audio track, where they never arrive at all - and this backend is the
  /// singleton for music and audiobooks too. The display query enumerates
  /// every display path.
  ///
  /// [engageMpv] must return false if mpv refused the handle, so the failure
  /// is recorded rather than leaving a black window on screen.
  Future<int?> maybeEngage({
    required bool preferenceEnabled,
    required Future<bool> Function() isHdrContent,
    required Future<bool> Function() displayInHdrMode,
    required Future<bool> Function(int handle) engageMpv,
  }) async {
    if (isEngaged) {
      return window.handle;
    }
    if (hasFailed || _deciding || !presenterActive) {
      return null;
    }
    _deciding = true;
    try {
      return await _decide(
        preferenceEnabled: preferenceEnabled,
        isHdrContent: isHdrContent,
        displayInHdrMode: displayInHdrMode,
        engageMpv: engageMpv,
      );
    } finally {
      _deciding = false;
    }
  }

  Future<int?> _decide({
    required bool preferenceEnabled,
    required Future<bool> Function() isHdrContent,
    required Future<bool> Function() displayInHdrMode,
    required Future<bool> Function(int handle) engageMpv,
  }) async {
    if (!preferenceEnabled) {
      status.value = HdrOutputStatus.disabledByPreference;
      return null;
    }
    if (!await isHdrContent()) {
      status.value = HdrOutputStatus.contentIsSdr;
      return null;
    }
    if (!await displayInHdrMode()) {
      // Switching the display is the auto-HDR preference's job, and it runs
      // before this. If it is off, or the display refused, there is nothing
      // useful to send.
      status.value = HdrOutputStatus.displayNotInHdrMode;
      return null;
    }

    final handle = await window.create();
    if (handle == null) {
      status.value = HdrOutputStatus.failed;
      return null;
    }

    if (!await engageMpv(handle)) {
      await window.destroy();
      status.value = HdrOutputStatus.failed;
      return null;
    }

    status.value = HdrOutputStatus.active;
    return handle;
  }
}

/// Whether what mpv decoded is HDR.
///
/// mpv is the better source than the server's `VideoRangeType`, which can be
/// missing or wrong — what matters is what actually decoded. But it cannot
/// answer for **Dolby Vision Profile 5**: that has no HDR10 base layer and
/// frequently no VUI transfer characteristic, so the picture is IPT and only
/// becomes BT.2020 PQ once libplacebo applies the RPU — which happens under
/// `gpu-next`, which is the very thing being decided. mpv reports a P5 title
/// as SDR right up until it stops being one.
///
/// BT.2020 primaries break that tie: IPT is carried on them, so they are
/// present even when the transfer characteristic is not. Wide-gamut SDR also
/// matches, and the cost of being wrong there is only that mpv tone-maps in
/// its own window rather than the texture, on a display already in HDR mode
/// since that is a precondition for reaching this at all.
bool isHdrVideoParams({required String? gamma, required String? primaries}) {
  final transfer = gamma?.toLowerCase() ?? '';
  if (transfer == 'pq' || transfer == 'st2084' || transfer == 'hlg') {
    return true;
  }
  return (primaries?.toLowerCase() ?? '').contains('2020');
}
