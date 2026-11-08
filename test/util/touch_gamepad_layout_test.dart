import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/game_cores.dart';
import 'package:moonfin/util/native_controller_mapping.dart';
import 'package:moonfin/util/touch_gamepad_layout.dart';

/// Hit shapes for the overlap check: a cross is its two arms, a circle is a
/// circle, tabs and pills are their boxes.
List<Object> _shapes(PlacedControl p) {
  final c = p.control, r = p.rect;
  if (c.kind == TouchControlKind.dpad) {
    final arm = r.width * 0.34;
    return [
      Rect.fromCenter(center: r.center, width: arm, height: r.height),
      Rect.fromCenter(center: r.center, width: r.width, height: arm),
    ];
  }
  if (c.shape == TouchShape.circle) return [r.center & Size(r.width, 0)];
  return [r];
}

bool _hit(Object a, Object b) {
  if (a is Rect && b is Rect) return a.overlaps(b);
  // A circle is encoded as a zero-height rect whose width is the diameter.
  Rect rect;
  Rect circ;
  if (a is Rect && a.height == 0) {
    circ = a;
    rect = b as Rect;
  } else {
    circ = b as Rect;
    rect = a as Rect;
  }
  final radius = circ.width / 2;
  if (rect.height == 0) {
    return (circ.topLeft - rect.topLeft).distance <
        radius + rect.width / 2 - 0.5;
  }
  final nx = circ.left.clamp(rect.left, rect.right);
  final ny = circ.top.clamp(rect.top, rect.bottom);
  return (Offset(nx, ny) - circ.topLeft).distance < radius - 0.5;
}

void main() {
  final cores = {
    for (final core in gameCoreCatalog) ...core.emulatorJsSystemCores,
  };
  const sizes = {false: Size(844, 390), true: Size(390, 844)};

  test('RetroPadId uses libretro names, unlike RetroPadButton', () {
    expect(RetroPadId.b, 0);
    expect(RetroPadId.a, 8);
    expect(RetroPadId.l2, 12);
    // Xbox naming: 'a' is libretro's B. Both tables exist on purpose.
    expect(RetroPadButton.values.first.name, 'a');
    expect(RetroPadButton.values.first.index, RetroPadId.b);
  });

  test('every native system has a shell with no dead or missing button', () {
    for (final core in cores) {
      final layout = touchPadLayoutFor(core);
      final buttons = layout.controls.where(
        (c) => c.kind == TouchControlKind.button,
      );
      expect(buttons, isNotEmpty, reason: core);
      for (final b in buttons) {
        expect(b.mask, isNot(0), reason: '$core ${b.label}');
      }
      // WonderSwan steers with four X buttons, so a button sending a d-pad
      // bit counts as a direction control too.
      const dpadMask =
          (1 << RetroPadId.up) |
          (1 << RetroPadId.down) |
          (1 << RetroPadId.left) |
          (1 << RetroPadId.right);
      expect(
        layout.controls.any(
          (c) =>
              c.kind == TouchControlKind.dpad ||
              c.kind == TouchControlKind.stick ||
              c.mask & dpadMask != 0,
        ),
        isTrue,
        reason: '$core needs a direction control',
      );
    }
  });

  test('PlayStation sticks appear only for an analog pad type', () {
    bool hasStick(TouchPadLayout l) =>
        l.controls.any((c) => c.kind == TouchControlKind.stick);
    expect(hasStick(touchPadLayoutFor('psx')), isFalse);
    expect(hasStick(touchPadLayoutFor('psx', padType: 517)), isTrue);
    expect(
      touchPadLayoutFor(
        'psx',
        padType: 517,
      ).controls.firstWhere((c) => c.label == 'ANALOG').mask,
      (1 << RetroPadId.l) | (1 << RetroPadId.r) | (1 << RetroPadId.select),
    );
  });

  test('a stick on a port the core reads digitally snaps to the d-pad', () {
    final digital = touchPadLayoutFor('n64').controls
        .firstWhere((c) => c.label == 'Control stick');
    final analog = touchPadLayoutFor(
      'n64',
      analogPorts: 1,
    ).controls.firstWhere((c) => c.label == 'Control stick');
    expect(digital.digital, isTrue);
    expect(analog.digital, isFalse);
  });

  test('every control fits on screen and none overlap, both ways up', () {
    final cases = [
      for (final core in cores) (core, 4 / 3, 1),
      ('nds', 2 / 3, 1),
      ('arcade', 3 / 4, 1),
      ('psx', 4 / 3, 517),
    ];
    for (final (core, aspect, padType) in cases) {
      for (final MapEntry(key: portrait, value: size) in sizes.entries) {
        final picture = gamePictureRect(
          size,
          EdgeInsets.zero,
          aspect,
          portrait: portrait,
        );
        final layout = touchPadLayoutFor(
          core,
          tall: portrait,
          padType: padType,
        );
        final placed = placeTouchPad(
          layout,
          size,
          EdgeInsets.zero,
          picture,
          portrait: portrait,
        );
        final screen = Offset.zero & size;
        for (final p in placed) {
          expect(
            screen.contains(p.rect.topLeft) &&
                screen.contains(p.rect.bottomRight),
            isTrue,
            reason:
                '$core ${portrait ? 'upright' : 'sideways'} '
                '${p.control.label} at ${p.rect}',
          );
        }
        for (var i = 0; i < placed.length; i++) {
          for (var j = i + 1; j < placed.length; j++) {
            final a = placed[i], b = placed[j];
            final overlap = _shapes(a)
                .any((sa) => _shapes(b).any((sb) => _hit(sa, sb)));
            expect(
              overlap,
              isFalse,
              reason:
                  '$core ${portrait ? 'upright' : 'sideways'}: '
                  '${a.control.label} overlaps ${b.control.label}',
            );
          }
        }
        if (portrait) {
          for (final p in placed) {
            expect(
              p.rect.top >= picture.bottom - 0.5,
              isTrue,
              reason: '$core ${p.control.label} covers the picture',
            );
          }
        } else if (layout.touchScreen && aspect == 2 / 3) {
          // The lower half of a real DS picture is its touch screen.
          final lower = Rect.fromLTRB(
            picture.left,
            picture.center.dy,
            picture.right,
            picture.bottom,
          );
          for (final p in placed) {
            expect(
              p.rect.overlaps(lower),
              isFalse,
              reason: '$core ${p.control.label} covers the touch screen',
            );
          }
        }
      }
    }
  });

  test('upright, the DualShock sticks share a row centred under the pads', () {
    const size = Size(390, 844);
    final picture = gamePictureRect(
      size,
      EdgeInsets.zero,
      4 / 3,
      portrait: true,
    );
    final placed = placeTouchPad(
      touchPadLayoutFor('psx', tall: true, padType: 517),
      size,
      EdgeInsets.zero,
      picture,
      portrait: true,
    );
    PlacedControl find(String label) =>
        placed.firstWhere((p) => p.control.label == label);
    final left = find('Left stick'), right = find('Right stick');
    expect(left.center.dy, closeTo(right.center.dy, 0.5));
    expect(left.center.dx, closeTo(find('D-pad').center.dx, 0.5));
    expect(left.center.dx + right.center.dx, closeTo(size.width, 0.5));
  });

  test('the picture pins to the top upright and keeps room for the pad', () {
    const size = Size(390, 844);
    final ds = gamePictureRect(size, EdgeInsets.zero, 2 / 3, portrait: true);
    expect(ds, const Rect.fromLTWH(0, 0, 390, 585));
    // Under a status bar the tall DS picture gives up a few pixels so the pad
    // keeps its minimum height.
    final inset = gamePictureRect(
      size,
      const EdgeInsets.only(top: 44),
      2 / 3,
      portrait: true,
    );
    expect(inset.top, 44);
    expect(inset.width, lessThan(390));
    expect(size.height - inset.bottom, greaterThanOrEqualTo(220));
    final sideways = gamePictureRect(
      const Size(844, 390),
      EdgeInsets.zero,
      4 / 3,
      portrait: false,
    );
    expect(sideways, const Rect.fromLTWH(162, 0, 520, 390));
  });

  test('d-pad bits snap to 8 directions outside the dead zone', () {
    const ids = [
      RetroPadId.up,
      RetroPadId.down,
      RetroPadId.left,
      RetroPadId.right,
    ];
    expect(dpadBitsFor(const Offset(3, 0), 10, ids), 0);
    expect(dpadBitsFor(const Offset(40, 0), 10, ids), 1 << RetroPadId.right);
    expect(
      dpadBitsFor(const Offset(30, -30), 10, ids),
      (1 << RetroPadId.right) | (1 << RetroPadId.up),
    );
    expect(dpadBitsFor(const Offset(0, 40), 10, ids), 1 << RetroPadId.down);
    expect(stickVector(const Offset(200, 0), 50), const Offset(1, 0));
    expect(stickVector(const Offset(25, 0), 50), const Offset(0.5, 0));
  });
}
