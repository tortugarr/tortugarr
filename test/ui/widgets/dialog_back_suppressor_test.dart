import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/widgets/overlay_sheet.dart';

// Issue #1704: before Android 13, a menu closed with Back in the player never
// got its follow-up popRoute, so the leftover mark swallowed the first Back on
// the page the player returned to.

void main() {
  tearDown(DialogBackSuppressor.newBackPress);

  test('a mark from an earlier press is dropped when a new press starts', () {
    DialogBackSuppressor.markDismissed();

    DialogBackSuppressor.newBackPress();

    expect(DialogBackSuppressor.consume(), isFalse);
  });

  test('a mark from the current press still swallows its follow-up', () {
    DialogBackSuppressor.newBackPress();
    DialogBackSuppressor.markDismissed();

    expect(DialogBackSuppressor.consume(), isTrue);
    expect(DialogBackSuppressor.consume(), isFalse);
  });
}
