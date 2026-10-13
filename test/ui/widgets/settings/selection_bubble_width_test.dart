import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/settings/preference_tiles.dart';

// ListTile gives its trailing whatever width it asks for, so an unconstrained
// value bubble with a long label squeezed the title into a one character wide
// column. Tiles pass short values now, but a translation can still be long, so
// the cap is what keeps the title readable.
void main() {
  Future<void> pump(WidgetTester tester, String label) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ListTile(
              leading: const Icon(Icons.surround_sound),
              title: const Text('Passthrough', key: Key('title')),
              subtitle: const Text(
                'How compressed surround sound reaches your TV or receiver.',
              ),
              trailing: buildSettingsSelectionBubble(context, label, false),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a long value label leaves the title most of the row', (
    tester,
  ) async {
    await pump(tester, 'Auto (match detected device support)');

    final titleWidth = tester.getSize(find.byKey(const Key('title'))).width;
    expect(
      titleWidth,
      greaterThan(120),
      reason: 'the title column must stay readable next to a long value',
    );
  });

  testWidgets('a short value label is not stretched', (tester) async {
    await pump(tester, 'Off');

    final bubble = tester.getSize(
      find.ancestor(of: find.text('Off'), matching: find.byType(Container)),
    );
    expect(bubble.width, lessThan(80));
  });
}
