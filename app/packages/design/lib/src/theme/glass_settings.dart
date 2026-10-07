import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassQuality;

/// Rendering tier for glass surfaces, from richest to cheapest.
///
/// [liquid] and [frost] draw a real backdrop blur. [sheen] fakes the frosted
/// look with translucent tints, a hairline and a top highlight, using no blur
/// at all, which keeps it cheap on weak GPUs such as Android TV boxes running
/// Skia. [solid] is the flat fallback used by non-glass themes.
enum GlassTier { liquid, frost, sheen, solid }

/// Session-wide glass configuration for the design package.
///
/// The design package cannot see platform detection or user preferences, so
/// the app resolves the tier (GlassCapability.apply) at startup and on every
/// Glass Quality or interface-style change, then pushes it here, following
/// the same convention as ThemeRegistry.active.
class GlassSettings {
  GlassSettings._();

  // GPU cost of BackdropFilter scales with sigma while perceived frost
  // barely changes above 18, so both blur tiers share the same ceiling.
  static const double liquidSigmaCap = 18;
  static const double frostSigmaCap = 18;

  static GlassTier tier = GlassTier.solid;

  /// Whether the root GlassBackdrop may animate. The app leaves it off on
  /// every tier because the drift redraws the full-screen bloom stack each
  /// frame, which was a major thermal cost.
  static bool animatedBackdrop = false;

  /// When true, blur tiers delegate the frosted layer of every pane to the
  /// liquid_glass_widgets renderer instead of a raw BackdropFilter, with
  /// quality governed by the app's GlassAdaptiveScope. Pushed by
  /// GlassCapability.apply, like [tier]. Sheen and solid always stay on the
  /// hand-rolled path because zero blur is cheaper than anything the
  /// package offers.
  static bool usePackageRenderer = false;

  /// The adaptive scope's settled quality, pushed by the app whenever the
  /// scope steps up or down. Only meaningful while [usePackageRenderer] is
  /// true. Lets sigma caps and the root backdrop track device pressure.
  static GlassQuality packageQuality = GlassQuality.standard;

  /// True when the current tier renders a real BackdropFilter.
  static bool get blursBackdrop =>
      tier == GlassTier.liquid || tier == GlassTier.frost;

  /// True when the root GlassBackdrop should collapse its bloom stack into a
  /// single gradient pass. Always on sheen, and under the package renderer
  /// once the adaptive scope has throttled down to minimal, since a device
  /// under pressure shouldn't pay for six full-screen draws either.
  static bool get cheapBackdrop =>
      tier == GlassTier.sheen ||
      (usePackageRenderer && packageQuality == GlassQuality.minimal);

  /// Clamps a requested blur sigma to the current tier's budget.
  static double capSigma(double requested) => capSigmaFor(tier, requested);

  /// Sigma ceiling once the adaptive scope has throttled to minimal. Keeps
  /// the raw BackdropFilter call sites (toolbars, media bar, detail scrims)
  /// under the same pressure response as package-rendered panes without
  /// touching those call sites, since they all clamp through [capSigma].
  static const double minimalSigmaCap = 10;

  static double capSigmaFor(GlassTier tier, double requested) {
    switch (tier) {
      case GlassTier.liquid:
      case GlassTier.frost:
        final tierCap =
            tier == GlassTier.liquid ? liquidSigmaCap : frostSigmaCap;
        final throttled =
            usePackageRenderer && packageQuality == GlassQuality.minimal;
        final cap = throttled && minimalSigmaCap < tierCap
            ? minimalSigmaCap
            : tierCap;
        return requested > cap ? cap : requested;
      case GlassTier.sheen:
      case GlassTier.solid:
        return 0;
    }
  }

  /// Sigma for decorative blurs of a widget's own image, where the blur is
  /// part of the artwork treatment. Blur tiers get the normal cap; sheen
  /// keeps a reduced blur instead of dropping the effect, because these
  /// images look broken when shown sharp.
  static double decorativeSigma(double requested) {
    if (blursBackdrop) return capSigma(requested);
    return requested > 12 ? 12 : requested;
  }
}
