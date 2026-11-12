import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/home/home_row_shift.dart';

void main() {
  const extents = [300.0, 200.0, 250.0, 180.0];

  test('rows above and the focused row keep their size', () {
    for (final i in [0, 1]) {
      expect(harborRowLookFor(rowIndex: i, focusedRowIndex: 1, rowExtents: extents), HarborRowLook.normal);
    }
  });

  test('with focus outside the rows (spotlight) nothing shrinks', () {
    expect(harborRowLookFor(rowIndex: 2, focusedRowIndex: null, rowExtents: extents), HarborRowLook.normal);
  });

  test('the first row below shrinks in place, later ones close the gap above them', () {
    final first = harborRowLookFor(rowIndex: 1, focusedRowIndex: 0, rowExtents: extents);
    expect(first.scale, harborBelowRowScale);
    expect(first.lift, 0);
    final third = harborRowLookFor(rowIndex: 3, focusedRowIndex: 0, rowExtents: extents);
    expect(third.lift, closeTo((200 + 250) * (1 - harborBelowRowScale), 1e-9));
    expect(third.opacity, lessThan(1));
  });
}
