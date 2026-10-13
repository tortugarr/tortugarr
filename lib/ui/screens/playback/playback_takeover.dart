import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Releases decoded-image memory before a full-screen playback surface takes
/// over.
///
/// Games and video are memory-hungry in a way the rest of the app is not. The
/// game hosts allocate frame buffers plus a core's own heap, or run a whole
/// WebAssembly emulator in a separate WebView process the OS kills outright
/// when memory runs short (buglog bug-033, a 3 GB Shield with ~46 MB free).
/// A 4K Dolby Vision decode is no lighter, the codec alone was holding 75 MB
/// of graphics buffers when a 2 GB onn box was killed mid-playback.
///
/// Pausing artwork work stops new allocations but frees nothing already
/// resident. This drops what is held, so the memory goes to the decoder
/// instead. Nothing artwork-backed is visible behind a full-screen surface,
/// so clearing live images costs only a re-decode of whatever the user
/// returns to, and buys headroom on exactly the low-end hardware that needs
/// it most.
void releaseImageMemoryForPlayback() {
  final cache = PaintingBinding.instance.imageCache;
  cache.clear();
  cache.clearLiveImages();
}

/// Detaches any lingering IME connection before a playback surface takes over
/// input.
///
/// The browse and search screens have text fields, and focusing one binds the
/// system IME to this app. That binding is not released when the field loses
/// focus, Android keeps `mBoundToMethod=true` with `mServedView=null`, so
/// every subsequent key, including the d-pad, is offered to the IME before it
/// reaches us. Once the IME's channel goes stale that send fails (EPIPE), and
/// the input dispatcher then holds the next key back, logging "Waiting to
/// send key ... because there are unprocessed events that may cause focus to
/// change". The symptom is exactly what it sounds like: presses that arrive
/// late or appear to stick.
///
/// Nothing on a full-screen playback surface wants a text connection, so drop
/// it on the way in. Flutter re-attaches on its own the next time a field is
/// focused, via the setClient it always sends.
void detachTextInputForPlayback() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  SystemChannels.textInput.invokeMethod<void>('TextInput.clearClient');
}
