import 'dart:math' as math;
import 'dart:ui';

/// Pulls saved window bounds back onto a screen they fit on. Geometry written
/// while the window was maximized reaches past every edge, since Windows
/// inflates a maximized frame by its invisible resize border, and a display
/// that has been unplugged or changed resolution leaves the same kind of
/// rectangle behind. Either one puts the title bar out of reach on the next
/// launch.
///
/// The window keeps its size wherever it still fits, and moves only as far as
/// it takes to sit inside the work area it already overlaps most.
Rect fitBoundsToWorkAreas(Rect saved, List<Rect> workAreas) {
  // Nothing to fit them to, so they stay as they are.
  if (workAreas.isEmpty) return saved;

  var area = workAreas.first;
  var bestOverlap = -1.0;
  for (final candidate in workAreas) {
    final overlap = candidate.intersect(saved);
    final covered = overlap.width <= 0 || overlap.height <= 0
        ? 0.0
        : overlap.width * overlap.height;
    if (covered > bestOverlap) {
      bestOverlap = covered;
      area = candidate;
    }
  }

  final width = math.min(saved.width, area.width);
  final height = math.min(saved.height, area.height);
  return Rect.fromLTWH(
    saved.left.clamp(area.left, math.max(area.left, area.right - width)),
    saved.top.clamp(area.top, math.max(area.top, area.bottom - height)),
    width,
    height,
  );
}
