import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassQuality;
import 'package:moonfin_design/moonfin_design.dart';

/// Covers which backdrop primitive each [GlassTier] produces with the
/// package renderer on and off, plus the sigma cap and cheap backdrop
/// shims that govern call sites outside glassPane.
void main() {
  setUp(() {
    GlassSettings.tier = GlassTier.solid;
    GlassSettings.usePackageRenderer = false;
    GlassSettings.packageQuality = GlassQuality.standard;
  });

  Widget host(Widget child) =>
      Directionality(textDirection: TextDirection.ltr, child: child);

  group('glassPane backdrop primitive per tier', () {
    testWidgets('solid renders a flat DecoratedBox, no blur, no package',
        (tester) async {
      await tester.pumpWidget(host(glassPane(
        tier: GlassTier.solid,
        fallbackColor: const Color(0xFF101620),
      )));
      expect(find.byType(DecoratedBox), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassContainer), findsNothing);
    });

    testWidgets('sheen renders zero-blur pane, no package', (tester) async {
      await tester.pumpWidget(host(glassPane(
        tier: GlassTier.sheen,
        fallbackColor: const Color(0xFF101620),
      )));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassContainer), findsNothing);
    });

    testWidgets('frost on legacy path renders a raw BackdropFilter',
        (tester) async {
      await tester.pumpWidget(host(glassPane(
        tier: GlassTier.frost,
        fallbackColor: const Color(0xFF101620),
      )));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(GlassContainer), findsNothing);
    });

    testWidgets('frost with package renderer delegates to GlassContainer',
        (tester) async {
      GlassSettings.usePackageRenderer = true;
      await tester.pumpWidget(host(glassPane(
        tier: GlassTier.frost,
        fallbackColor: const Color(0xFF101620),
      )));
      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('liquid with package renderer delegates to GlassContainer',
        (tester) async {
      GlassSettings.usePackageRenderer = true;
      await tester.pumpWidget(host(glassPane(
        tier: GlassTier.liquid,
        fallbackColor: const Color(0xFF101620),
      )));
      expect(find.byType(GlassContainer), findsOneWidget);
    });
  });

  group('sigma caps', () {
    test('blur tiers clamp to the shared 18 ceiling', () {
      expect(GlassSettings.capSigmaFor(GlassTier.liquid, 32), 18);
      expect(GlassSettings.capSigmaFor(GlassTier.frost, 32), 18);
      expect(GlassSettings.capSigmaFor(GlassTier.liquid, 14), 14);
    });

    test('sheen and solid always clamp to zero', () {
      expect(GlassSettings.capSigmaFor(GlassTier.sheen, 20), 0);
      expect(GlassSettings.capSigmaFor(GlassTier.solid, 20), 0);
    });

    test('adaptive minimal throttle tightens blur tiers to 10', () {
      GlassSettings.usePackageRenderer = true;
      GlassSettings.packageQuality = GlassQuality.minimal;
      expect(GlassSettings.capSigmaFor(GlassTier.liquid, 20), 10);
      expect(GlassSettings.capSigmaFor(GlassTier.frost, 20), 10);
      expect(GlassSettings.capSigmaFor(GlassTier.frost, 8), 8);
    });

    test('minimal quality without package renderer does not throttle', () {
      GlassSettings.packageQuality = GlassQuality.minimal;
      expect(GlassSettings.capSigmaFor(GlassTier.frost, 20), 18);
    });
  });

  group('cheapBackdrop', () {
    test('true on sheen tier', () {
      GlassSettings.tier = GlassTier.sheen;
      expect(GlassSettings.cheapBackdrop, isTrue);
    });

    test('true when adaptive scope has throttled to minimal', () {
      GlassSettings.tier = GlassTier.liquid;
      GlassSettings.usePackageRenderer = true;
      GlassSettings.packageQuality = GlassQuality.minimal;
      expect(GlassSettings.cheapBackdrop, isTrue);
    });

    test('false on blur tiers at standard quality', () {
      GlassSettings.tier = GlassTier.liquid;
      GlassSettings.usePackageRenderer = true;
      GlassSettings.packageQuality = GlassQuality.standard;
      expect(GlassSettings.cheapBackdrop, isFalse);
    });
  });
}
