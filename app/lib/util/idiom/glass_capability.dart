import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:moonfin_design/moonfin_design.dart'
    show AppColorScheme, GlassQuality, GlassSettings, GlassTier;

import '../../preference/preference_constants.dart';
import '../platform_detection.dart';
import 'app_ui_idiom.dart';

export 'package:moonfin_design/moonfin_design.dart' show GlassTier;

class GlassCapability {
  GlassCapability._();

  /// Kill switch for the liquid_glass_widgets renderer. When true, every
  /// platform stays on the hand-rolled BackdropFilter path.
  static const bool useLegacyGlass = false;

  /// Ceiling handed to the app-shell GlassAdaptiveScope. Premium is
  /// Impeller-only and unreliable inside scroll views, and Moonfin is
  /// scroll-heavy, so the ceiling stays at standard.
  static const GlassQuality adaptiveMaxQuality = GlassQuality.standard;

  /// Called by the app shell whenever the adaptive scope settles on a new
  /// quality, so sigma caps and the root backdrop track device pressure.
  static void onAdaptiveQualityChanged(GlassQuality from, GlassQuality to) {
    GlassSettings.packageQuality = to;
  }

  /// Whether the glass look applies at adaptive call sites. Always true under
  /// Apple idioms (including leanback), and under the glass theme on every
  /// platform. Sites where this is false fall back to solid surfaces.
  static bool get glassLookActive =>
      AppColorScheme.isGlass ||
      AppUiIdiomResolver.isApple ||
      AppUiIdiomResolver.current == AppUiIdiom.tvosLeanback;

  /// Resolves the glass rendering tier from platform capability and the
  /// Glass Quality preference. This only decides how glass is drawn; whether
  /// a call site draws glass at all is gated there (glass theme or Apple
  /// idiom).
  static GlassTier resolve(GlassQualityMode quality) {
    if (quality == GlassQualityMode.reduced) return GlassTier.sheen;
    // CanvasKit backdrop blur across the shell is a known jank source.
    if (kIsWeb) return GlassTier.sheen;
    if (PlatformDetection.isAppleTV) return GlassTier.frost;
    // TV boxes are the weakest GPUs we ship to and default to Skia, where
    // BackdropFilter is most expensive, so real blur is opt-in via full.
    if (PlatformDetection.isTV) {
      return quality == GlassQualityMode.full
          ? GlassTier.frost
          : GlassTier.sheen;
    }
    if ((PlatformDetection.isIOS || PlatformDetection.isMacOS) &&
        PlatformDetection.osMajor >= 26) {
      return GlassTier.liquid;
    }
    // Older Apple, Android mobile, Windows/Linux desktop.
    return GlassTier.frost;
  }

  /// Recomputes the tier and pushes it into the design package. Called at
  /// startup (after TV-mode detection) and whenever the Glass Quality or
  /// interface-style preference changes.
  static void apply(GlassQualityMode quality) {
    final tier = resolve(quality);
    GlassSettings.tier = tier;
    // Blur-capable tiers delegate their frosted layer to the
    // liquid_glass_widgets renderer, governed by the app-shell adaptive
    // scope. Sheen and solid keep the hand-rolled zero-blur path, which is
    // cheaper than anything the package offers, so it stays the floor for
    // weak TV boxes, web, and the reduced preference.
    GlassSettings.usePackageRenderer = !useLegacyGlass &&
        (tier == GlassTier.liquid || tier == GlassTier.frost);
    // The 16s backdrop drift redrew the full-screen bloom stack every frame
    // and was the single largest continuous GPU draw on the liquid tier, a
    // major contributor to iPhones running hot on the glass theme. The
    // backdrop stays static on every tier now.
    GlassSettings.animatedBackdrop = false;
  }
}
