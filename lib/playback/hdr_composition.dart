import 'hdr_composition_stub.dart'
    if (dart.library.io) 'hdr_composition_io.dart'
    as impl;

/// How the native HDR video window is composited with the Flutter UI.
///
/// Default (technique 2): mpv renders into a top-level window *behind* the
/// runner window, and the runner is given per-pixel DWM transparency, so
/// Flutter draws controls, dialogs and OSD natively over the video with no
/// capture at all.
///
/// `MOONFIN_HDR_DWM=0` selects the overlay-capture fallback: mpv's window sits
/// *above* the Flutter view and the player chrome is mirrored over it through
/// a layered window. Menus need the video stood down and every chrome frame
/// is a readback. `1..4` picks a specific transparency technique for the
/// behind arrangement.
///
/// Parsed once here; the runner receives the mode with the video window's
/// `create` call.
abstract final class HdrComposition {
  /// 1..4 = DWM transparency technique (2 is the default). 0 = the
  /// overlay-capture fallback.
  static final int dwmMode = impl.readDwmMode();

  /// Whether the video window sits behind a transparent Flutter window, so
  /// no capture or stand-down is needed.
  static bool get videoBehindFlutter => dwmMode != 0;
}
