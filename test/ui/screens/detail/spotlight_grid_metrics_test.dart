// The Spotlight modal grids share one column and cell computation. Pin the
// numbers so a layout tweak in one grid can't silently shift the others.
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/detail/spotlight/widgets/spotlight_modal_grids.dart';
import 'package:moonfin/ui/widgets/media_card.dart';

void main() {
  test('a 1000px poster grid fits six 156px columns', () {
    final metrics = spotlightGridMetrics(
      maxWidth: 1000,
      desiredWidth: 150,
      minColumns: 2,
      maxColumns: 7,
      maxCellWidth: 300,
    );
    expect(metrics.columns, 6);
    expect(metrics.cellWidth, 156);
    expect(metrics.spacing, 12);
    expect(metrics.runSpacing, 16);
  });

  test('a 600px people grid fits four 138px cells at 16px gaps', () {
    final metrics = spotlightGridMetrics(
      maxWidth: 600,
      desiredWidth: 110,
      minColumns: 3,
      maxColumns: 9,
      minSpacing: 16,
      minRunSpacing: 16,
    );
    expect(metrics.columns, 4);
    expect(metrics.cellWidth, 138);
    expect(metrics.spacing, 16);
    expect(metrics.runSpacing, 16);
  });

  test('the column count is clamped to the allowed range', () {
    expect(
      spotlightGridMetrics(
        maxWidth: 100,
        desiredWidth: 150,
        minColumns: 2,
        maxColumns: 7,
      ).columns,
      2,
    );
    expect(
      spotlightGridMetrics(
        maxWidth: 5000,
        desiredWidth: 150,
        minColumns: 2,
        maxColumns: 7,
      ).columns,
      7,
    );
  });

  test('a cell never exceeds maxCellWidth', () {
    final metrics = spotlightGridMetrics(
      maxWidth: 5000,
      desiredWidth: 150,
      minColumns: 2,
      maxColumns: 7,
      maxCellWidth: 300,
    );
    expect(metrics.cellWidth, 300);
  });

  test('focus expansion widens the gaps to the card focus gap', () {
    final metrics = spotlightGridMetrics(
      maxWidth: 1000,
      desiredWidth: 150,
      minColumns: 2,
      maxColumns: 7,
      maxCellWidth: 300,
      focusExpansion: true,
    );
    expect(metrics.columns, 6);
    // The first pass at the minimum gap gives 156px cells; the gap is then
    // sized off that width and the cells re-measured against it.
    expect(metrics.spacing, MediaCard.focusGap(156, minimum: 12));
    expect(
      metrics.cellWidth,
      ((1000 - metrics.spacing * 5) / 6).floorToDouble(),
    );
    expect(
      metrics.runSpacing,
      MediaCard.focusGap(metrics.cellWidth / (2 / 3), minimum: 16),
    );
  });
}
