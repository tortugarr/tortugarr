import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'native_controller_mapping.dart';

/// RetroPad ids with libretro's names. The bit a control sends is `1 << id`.
///
/// Not to be confused with [RetroPadButton] in native_controller_mapping.dart,
/// which uses Xbox naming: its index 0 is 'a', libretro's id 0 is B.
abstract final class RetroPadId {
  static const int b = 0;
  static const int y = 1;
  static const int select = 2;
  static const int start = 3;
  static const int up = 4;
  static const int down = 5;
  static const int left = 6;
  static const int right = 7;
  static const int a = 8;
  static const int x = 9;
  static const int l = 10;
  static const int r = 11;
  static const int l2 = 12;
  static const int r2 = 13;
  static const int l3 = 14;
  static const int r3 = 15;
}

int _bit(int id) => 1 << id;

/// Up, down, left, right, the order [dpadBitsFor] expects.
const List<int> _dpadIds = [
  RetroPadId.up,
  RetroPadId.down,
  RetroPadId.left,
  RetroPadId.right,
];

enum TouchControlKind { button, dpad, stick, menu }

enum TouchShape { circle, tab, pill }

/// Which placement rule positions a control: the two thumb clusters are laid
/// out from a cluster origin, the rest from the screen edges.
enum TouchCluster { left, right, shoulderLeft, shoulderRight, pills, menu }

class TouchControl {
  const TouchControl({
    required this.kind,
    required this.cluster,
    this.shape = TouchShape.circle,
    this.mask = 0,
    this.label = '',
    this.color = const Color(0xFF26262C),
    this.at = Offset.zero,
    this.size = 56,
    this.dpadIds = _dpadIds,
    this.digital = false,
    this.rightStick = false,
    this.glyph,
  });

  final TouchControlKind kind;
  final TouchCluster cluster;
  final TouchShape shape;

  /// Bits a button sends while held. The DualShock ANALOG pill holds three.
  final int mask;
  final String label;
  final Color color;

  /// Landscape pixels from the cluster origin, which the portrait rule rescales.
  final Offset at;

  /// Diameter of a circle or cross. Tabs and pills have fixed boxes.
  final double size;

  /// Up, down, left, right ids a d-pad or a snapped stick sends.
  final List<int> dpadIds;

  /// A stick that snaps to 8 directions and sends [dpadIds] instead of analog.
  final bool digital;

  /// A stick that drives the right analog stick (PS1 right, N64 C buttons).
  final bool rightStick;

  /// PlayStation face glyph: 'tri', 'cir', 'x' or 'sq'.
  final String? glyph;

  /// The libretro id for a one-bit button, used for the core's own label.
  int? get id {
    if (mask == 0 || mask & (mask - 1) != 0) return null;
    return mask.bitLength - 1;
  }

  TouchControl copyWith({required Offset at}) => TouchControl(
    kind: kind,
    cluster: cluster,
    shape: shape,
    mask: mask,
    label: label,
    color: color,
    at: at,
    size: size,
    dpadIds: dpadIds,
    digital: digital,
    rightStick: rightStick,
    glyph: glyph,
  );
}

class TouchPadLayout {
  const TouchPadLayout({
    required this.controls,
    this.touchScreen = false,
    this.pillColor = const Color(0xFF26262C),
  });

  final List<TouchControl> controls;

  /// Taps on the picture go to the core as pointer input (Nintendo DS).
  final bool touchScreen;
  final Color pillColor;
}

const Color _ink = Color(0xFF16161B);

TouchControl _btn(
  TouchCluster cluster,
  String label,
  int mask,
  Color color,
  double dx,
  double dy,
  double r, {
  String? glyph,
}) => TouchControl(
  kind: TouchControlKind.button,
  cluster: cluster,
  mask: mask,
  label: label,
  color: color,
  at: Offset(dx, dy),
  size: r * 2,
  glyph: glyph,
);

TouchControl _cross(
  TouchCluster cluster,
  double dx,
  double dy,
  double size, {
  Color color = _ink,
  List<int> ids = _dpadIds,
  String label = 'D-pad',
}) => TouchControl(
  kind: TouchControlKind.dpad,
  cluster: cluster,
  label: label,
  color: color,
  at: Offset(dx, dy),
  size: size,
  dpadIds: ids,
);

TouchControl _stick(
  TouchCluster cluster,
  String label,
  double dx,
  double dy,
  double r, {
  bool digital = false,
  bool rightStick = false,
}) => TouchControl(
  kind: TouchControlKind.stick,
  cluster: cluster,
  label: label,
  at: Offset(dx, dy),
  size: r * 2,
  digital: digital,
  rightStick: rightStick,
);

TouchControl _tab(TouchCluster cluster, String label, int id, Color color) =>
    TouchControl(
      kind: TouchControlKind.button,
      cluster: cluster,
      shape: TouchShape.tab,
      mask: _bit(id),
      label: label,
      color: color,
    );

TouchControl _pill(String label, int mask) => TouchControl(
  kind: TouchControlKind.button,
  cluster: TouchCluster.pills,
  shape: TouchShape.pill,
  mask: mask,
  label: label,
);

/// Face buttons, by the shape the console's controller had. [tall] is the
/// upright placement, where the sticks move to their own row.
List<TouchControl> _face(
  String lay,
  List<(String, int, Color, String?)> b, {
  bool tall = false,
  bool twin = false,
  double fdy = 0,
}) {
  TouchControl put(int i, double dx, double dy, double r) => _btn(
    TouchCluster.right,
    b[i].$1,
    b[i].$2,
    b[i].$3,
    dx,
    dy,
    r,
    glyph: b[i].$4,
  );
  return switch (lay) {
    'one' => [put(0, 10, 8, 44)],
    'row2' => [put(0, -38, 16, 32), put(1, 44, 16, 32)],
    'diag2' when twin && tall => [put(0, -28, 108, 27), put(1, 44, 86, 27)],
    'diag2' when twin => [put(0, -32, 60, 27), put(1, 42, 26, 27)],
    'diag2' => [put(0, -32, 30, 32), put(1, 42, -24, 32)],
    'arc3' => [put(0, -60, 30, 28), put(1, 2, 10, 28), put(2, 64, -10, 28)],
    'diamond' => [
      put(0, 0, fdy - 58, 28),
      put(1, 58, fdy, 28),
      put(2, 0, fdy + 58, 28),
      put(3, -58, fdy, 28),
    ],
    'grid6' => [
      put(0, -64, -36, 26),
      put(1, -2, -50, 26),
      put(2, 60, -50, 26),
      put(3, -72, 36, 26),
      put(4, -10, 22, 26),
      put(5, 52, 22, 26),
    ],
    _ => const [],
  };
}

const _psFace = [
  ('Triangle', 1 << RetroPadId.x, Color(0xFF3FB68B), 'tri'),
  ('Circle', 1 << RetroPadId.a, Color(0xFFE2453C), 'cir'),
  ('Cross', 1 << RetroPadId.b, Color(0xFF86A2E6), 'x'),
  ('Square', 1 << RetroPadId.y, Color(0xFFD985C2), 'sq'),
];

/// Four small round buttons around a centre, up right down left.
List<TouchControl> _ring(
  List<String> labels,
  List<int> ids,
  double cx,
  double cy,
  double off,
  double r,
  Color color,
) => [
  for (final (i, (dx, dy)) in const [(0, -1), (1, 0), (0, 1), (-1, 0)].indexed)
    _btn(
      TouchCluster.left,
      labels[i],
      _bit(ids[i]),
      color,
      cx + dx * off,
      cy + dy * off,
      r,
    ),
];

/// The pad for an EmulatorJS core id, one console shell per system: only the
/// buttons the console has, its labels and colors, and a plain stick where its
/// controller had one. PlayStation shows DualShock sticks only when [padType]
/// is an analog pad. A stick on a port the core doesn't read analog on
/// ([analogPorts] bit 0) snaps to the d-pad instead.
TouchPadLayout touchPadLayoutFor(
  String core, {
  bool tall = false,
  int padType = 1,
  int analogPorts = 0,
}) {
  final analog = analogPorts & 1 != 0;
  const grey = Color(0xFF8D8B99);
  const dark = Color(0xFF77757F);
  final L = <TouchControl>[];
  final F = <TouchControl>[];
  final sh = <TouchControl>[];
  final pills = <TouchControl>[];
  var pillColor = const Color(0xFF26262C);
  var touchScreen = false;
  var faceCenterOnDpad = true;
  const b = RetroPadId.b, a = RetroPadId.a, x = RetroPadId.x, y = RetroPadId.y;
  const sel = 1 << RetroPadId.select, start = 1 << RetroPadId.start;

  List<(String, int, Color, String?)> two(
    String first,
    String second,
    Color c,
  ) => [(first, _bit(b), c, null), (second, _bit(a), c, null)];

  switch (core) {
    case 'nes':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('row2', two('B', 'A', const Color(0xFFC8102E))));
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    case 'snes':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(
        _face('diamond', [
          ('X', _bit(x), const Color(0xFF2459C6), null),
          ('A', _bit(a), const Color(0xFFD62828), null),
          ('B', _bit(b), const Color(0xFFE0AC00), null),
          ('Y', _bit(y), const Color(0xFF2F9E44), null),
        ]),
      );
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, grey),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, grey),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    case 'gb':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('diag2', two('B', 'A', const Color(0xFF9A2257))));
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    case 'gba':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('diag2', two('B', 'A', const Color(0xFF55517A))));
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, grey),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, grey),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    case 'segaMD':
      // Three-button pad only. Six-button games also want X, Y, Z and Mode
      // (RetroPad L, X, R and Select) once the core reports a six-button pad.
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(
        _face('arc3', [
          ('A', _bit(y), const Color(0xFF18181C), null),
          ('B', _bit(b), const Color(0xFF18181C), null),
          ('C', _bit(a), const Color(0xFF18181C), null),
        ]),
      );
      pills.add(_pill('START', start));
    case 'segaMS':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('row2', two('1', '2', const Color(0xFF18181C))));
      pills.add(_pill('PAUSE', start));
    case 'segaGG':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('diag2', two('1', '2', const Color(0xFF2A2A32))));
      pills.add(_pill('START', start));
      pillColor = const Color(0xFF2A5BD7);
    case 'psx':
      final ds = pcsxAnalogPadTypes.contains(padType);
      faceCenterOnDpad = !ds;
      if (ds && tall) {
        L.add(_cross(TouchCluster.left, 0, 0, 128));
        L.add(
          _stick(TouchCluster.left, 'Left stick', 0, 140, 44, digital: !analog),
        );
        F.add(
          _stick(
            TouchCluster.right,
            'Right stick',
            0,
            140,
            44,
            digital: !analog,
            rightStick: true,
          ),
        );
      } else if (ds) {
        L.add(_cross(TouchCluster.left, 0, -80, 128));
        L.add(
          _stick(TouchCluster.left, 'Left stick', 0, 56, 44, digital: !analog),
        );
        F.add(
          _stick(
            TouchCluster.right,
            'Right stick',
            -70,
            64,
            44,
            digital: !analog,
            rightStick: true,
          ),
        );
      } else {
        L.add(_cross(TouchCluster.left, 0, 0, 156));
      }
      F.addAll(_face('diamond', _psFace, fdy: ds && !tall ? -36 : 0));
      const psGrey = Color(0xFF6C6A78);
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L2', RetroPadId.l2, psGrey),
        _tab(TouchCluster.shoulderLeft, 'L1', RetroPadId.l, psGrey),
        _tab(TouchCluster.shoulderRight, 'R2', RetroPadId.r2, psGrey),
        _tab(TouchCluster.shoulderRight, 'R1', RetroPadId.r, psGrey),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
      // pcsx_rearmed flips the DualShock's analog mode on exactly L1+R1+Select,
      // the default pcsx_rearmed_analog_combo.
      if (ds) {
        pills.add(
          _pill('ANALOG', _bit(RetroPadId.l) | _bit(RetroPadId.r) | sel),
        );
      }
    case 'arcade':
      L.add(_stick(TouchCluster.left, 'Joystick', 0, 0, 70, digital: true));
      F.addAll(
        _face('grid6', [
          ('LP', _bit(y), const Color(0xFFD62828), null),
          ('MP', _bit(x), const Color(0xFFE0AC00), null),
          ('HP', _bit(RetroPadId.l), const Color(0xFF2F9E44), null),
          ('LK', _bit(b), const Color(0xFF2459C6), null),
          ('MK', _bit(a), const Color(0xFF8A49D1), null),
          ('HK', _bit(RetroPadId.r), const Color(0xFFEF7D22), null),
        ]),
      );
      pills.addAll([_pill('COIN', sel), _pill('START', start)]);
    case 'n64':
      faceCenterOnDpad = false;
      L.add(_cross(TouchCluster.left, -8, -116, 84));
      L.add(
        _stick(
          TouchCluster.left,
          'Control stick',
          -8,
          14,
          62,
          digital: !analog,
        ),
      );
      // mupen64plus_next: N64 A is RetroPad B, N64 B is RetroPad Y, Z is L2,
      // and the C buttons are the right stick.
      F.add(
        _btn(
          TouchCluster.right,
          'B',
          _bit(y),
          const Color(0xFF2D9B4E),
          -42,
          -10,
          27,
        ),
      );
      F.add(
        _btn(
          TouchCluster.right,
          'A',
          _bit(b),
          const Color(0xFF2B5FD9),
          30,
          36,
          33,
        ),
      );
      // On a port the core reads digitally the C stick sends nothing, those
      // games need R2 held plus a face button instead.
      F.add(
        _stick(
          TouchCluster.right,
          'C buttons',
          30,
          tall ? -116 : -104,
          45,
          rightStick: true,
          digital: !analog,
        ),
      );
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, dark),
        _tab(TouchCluster.shoulderLeft, 'Z', RetroPadId.l2, dark),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, dark),
      ]);
      pills.add(_pill('START', start));
      pillColor = const Color(0xFFC42020);
    case 'psp':
      faceCenterOnDpad = false;
      L.add(_cross(TouchCluster.left, 0, tall ? 0 : -80, 128));
      L.add(
        _stick(
          TouchCluster.left,
          'Analog nub',
          0,
          tall ? 118 : 50,
          42,
          digital: !analog,
        ),
      );
      F.addAll(_face('diamond', _psFace));
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, dark),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, dark),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    case 'nds':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(
        _face('diamond', [
          ('X', _bit(x), const Color(0xFF4D4D57), null),
          ('A', _bit(a), const Color(0xFF4D4D57), null),
          ('B', _bit(b), const Color(0xFF4D4D57), null),
          ('Y', _bit(y), const Color(0xFF4D4D57), null),
        ]),
      );
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, dark),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, dark),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
      touchScreen = true;
    case 'pce':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('row2', two('II', 'I', const Color(0xFF202026))));
      pills.addAll([_pill('SELECT', sel), _pill('RUN', start)]);
    case 'atari2600':
      L.add(_stick(TouchCluster.left, 'Joystick', 0, 0, 70, digital: true));
      F.addAll(
        _face('one', [('FIRE', _bit(b), const Color(0xFFC0392B), null)]),
      );
      pills.addAll([
        _pill('DIFF L', _bit(RetroPadId.l)),
        _pill('SELECT', sel),
        _pill('RESET', start),
        _pill('DIFF R', _bit(RetroPadId.r)),
      ]);
      pillColor = const Color(0xFF3A2A1C);
    case 'atari7800':
      L.add(_stick(TouchCluster.left, 'Joystick', 0, 0, 70, digital: true));
      F.addAll(_face('row2', two('1', '2', const Color(0xFFC4561A))));
      pills.addAll([
        _pill('PAUSE', start),
        _pill('SELECT', sel),
        _pill('RESET', _bit(x)),
      ]);
      pillColor = const Color(0xFF3A2A1C);
    case 'lynx':
      L.add(_cross(TouchCluster.left, 0, 0, 156));
      F.addAll(_face('diag2', two('B', 'A', const Color(0xFF3D3D46))));
      pills.addAll([
        _pill('OPT 1', _bit(RetroPadId.l)),
        _pill('OPT 2', _bit(RetroPadId.r)),
        _pill('PAUSE', start),
      ]);
    case 'ws':
      // Landscape WonderSwan: the X pad steers and Y1..Y4 sit on R2 R L2 L.
      const padColor = Color(0xFF3A3A42);
      L.addAll(
        _ring(
          const ['X1', 'X2', 'X3', 'X4'],
          const [
            RetroPadId.up,
            RetroPadId.right,
            RetroPadId.down,
            RetroPadId.left,
          ],
          0,
          16,
          42,
          20,
          padColor,
        ),
      );
      L.addAll(
        _ring(
          const ['Y1', 'Y2', 'Y3', 'Y4'],
          const [RetroPadId.r2, RetroPadId.r, RetroPadId.l2, RetroPadId.l],
          0,
          -134,
          32,
          15,
          padColor,
        ),
      );
      F.addAll(_face('diag2', two('B', 'A', const Color(0xFF5C5C66))));
      pills.add(_pill('START', start));
    case 'ngp':
      L.add(_stick(TouchCluster.left, 'Joystick', 0, 0, 70, digital: true));
      F.addAll(_face('diag2', two('A', 'B', const Color(0xFF3A3A42))));
      pills.add(_pill('OPTION', start));
    case 'vb':
      faceCenterOnDpad = false;
      const red = Color(0xFF2A1215);
      L.add(
        _cross(TouchCluster.left, 0, 0, 144, color: red, label: 'Left D-pad'),
      );
      // Beetle VB puts the right pad on L2 (up), L3 (down), R2 (left), R3.
      F.add(
        _cross(
          TouchCluster.right,
          tall ? 0 : 12,
          tall ? 0 : -98,
          112,
          color: red,
          label: 'Right D-pad',
          ids: const [
            RetroPadId.l2,
            RetroPadId.l3,
            RetroPadId.r2,
            RetroPadId.r3,
          ],
        ),
      );
      F.addAll(
        _face(
          'diag2',
          two('B', 'A', const Color(0xFF3A3A42)),
          tall: tall,
          twin: true,
        ),
      );
      const vbGrey = Color(0xFF5A3A3E);
      sh.addAll([
        _tab(TouchCluster.shoulderLeft, 'L', RetroPadId.l, vbGrey),
        _tab(TouchCluster.shoulderRight, 'R', RetroPadId.r, vbGrey),
      ]);
      pills.addAll([_pill('SELECT', sel), _pill('START', start)]);
    default:
      // An unknown system gets the SNES shell, which has every common RetroPad
      // button.
      return touchPadLayoutFor('snes', tall: tall, analogPorts: analogPorts);
  }

  // Upright, single-row shells centre their face buttons on the d-pad's line
  // (WonderSwan on its X pad).
  if (tall && faceCenterOnDpad) {
    final buttons = F.where((c) => c.kind == TouchControlKind.button).toList();
    if (buttons.isNotEmpty) {
      final mid = buttons.fold(0.0, (s, c) => s + c.at.dy) / buttons.length;
      final to = core == 'ws' ? 16.0 : 0.0;
      for (var i = 0; i < F.length; i++) {
        F[i] = F[i].copyWith(at: F[i].at.translate(0, to - mid));
      }
    }
  }

  return TouchPadLayout(
    controls: [
      ...L,
      ...F,
      ...sh,
      ...pills,
      const TouchControl(
        kind: TouchControlKind.menu,
        cluster: TouchCluster.menu,
        label: 'Menu',
        size: 36,
      ),
    ],
    touchScreen: touchScreen,
    pillColor: pillColor,
  );
}

class PlacedControl {
  const PlacedControl(this.control, this.rect);
  final TouchControl control;
  final Rect rect;
  Offset get center => rect.center;
  double get radius => rect.width / 2;
}

/// Where the game picture goes. Landscape keeps the centred contain-fit.
/// Upright, the picture pins under the top inset at full width, shrinking only
/// if that would leave less than [minPadHeight] for the pad.
Rect gamePictureRect(
  Size size,
  EdgeInsets safe,
  double aspect, {
  required bool portrait,
  double minPadHeight = 220,
}) {
  if (!portrait) {
    final w = math.min(size.width, size.height * aspect);
    final h = w / aspect;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }
  var w = size.width;
  var h = w / aspect;
  final room = size.height - safe.top - minPadHeight;
  if (h > room) {
    h = math.max(room, size.width * 0.5);
    w = h * aspect;
  }
  return Rect.fromLTWH((size.width - w) / 2, safe.top, w, h);
}

class _Extent {
  double up = 0, down = 0, left = 0, right = 0;
  void add(TouchControl c) {
    final r = c.size / 2;
    up = math.max(up, r - c.at.dy);
    down = math.max(down, r + c.at.dy);
    left = math.max(left, r - c.at.dx);
    right = math.max(right, r + c.at.dx);
  }
}

const Size _tabSize = Size(124, 42);
const Size _tabSizeTall = Size(110, 40);
const Size _pillSize = Size(80, 28);

/// Absolute rects for every control. Landscape: thumb clusters at the bottom
/// corners, shoulders at the top corners, pills bottom centre or under the
/// shoulders for a touch screen, menu top centre.
/// Upright: the controller fills the space under [pictureRect], scaled to fit,
/// with the two clusters mirrored about the centre line so matching rows read
/// level.
List<PlacedControl> placeTouchPad(
  TouchPadLayout layout,
  Size size,
  EdgeInsets safe,
  Rect pictureRect, {
  required bool portrait,
}) {
  final w = size.width, h = size.height;
  final left = layout.controls.where((c) => c.cluster == TouchCluster.left);
  final right = layout.controls.where((c) => c.cluster == TouchCluster.right);
  final shL = layout.controls
      .where((c) => c.cluster == TouchCluster.shoulderLeft)
      .toList();
  final shR = layout.controls
      .where((c) => c.cluster == TouchCluster.shoulderRight)
      .toList();
  final pills = layout.controls
      .where((c) => c.cluster == TouchCluster.pills)
      .toList();

  double k, lx, fx, cy, tabY, tabStep, pillY, menuY;
  Size tab;
  if (!portrait) {
    k = 1;
    lx = safe.left + 112;
    fx = w - safe.right - 112;
    cy = h - safe.bottom - 114;
    tab = _tabSize;
    tabY = 14;
    tabStep = 50;
    pillY = h - safe.bottom - 42;
    menuY = 30;
  } else {
    final le = _Extent(), fe = _Extent();
    left.forEach(le.add);
    right.forEach(fe.add);
    final tabs = math.max(shL.length, shR.length);
    final top = pictureRect.bottom + (tabs > 0 ? 16 + tabs * 48 : 58);
    pillY = h - safe.bottom - 42;
    final bottom = pillY - 10;
    final up = math.max(le.up, fe.up), down = math.max(le.down, fe.down);
    final side = math.max(le.left, fe.right);
    k = [
      1.15,
      (bottom - top) / (up + down),
      (w - 36) / (2 * side + le.right + fe.left),
    ].reduce(math.min).clamp(0.6, 1.15);
    lx = 12 + side * k;
    fx = w - 12 - side * k;
    cy = top + up * k + ((bottom - top) - (up + down) * k) / 2;
    tab = _tabSizeTall;
    tabY = pictureRect.bottom + 12;
    tabStep = 48;
    menuY = pictureRect.bottom + 32;
  }

  Rect circle(Offset c, double d) =>
      Rect.fromCenter(center: c, width: d, height: d);
  final out = <PlacedControl>[];
  for (final c in left) {
    out.add(
      PlacedControl(
        c,
        circle(Offset(lx + c.at.dx * k, cy + c.at.dy * k), c.size * k),
      ),
    );
  }
  for (final c in right) {
    out.add(
      PlacedControl(
        c,
        circle(Offset(fx + c.at.dx * k, cy + c.at.dy * k), c.size * k),
      ),
    );
  }
  final tabX = portrait ? 12.0 : 16.0;
  for (final (i, c) in shL.indexed) {
    out.add(
      PlacedControl(
        c,
        Rect.fromLTWH(
          safe.left + tabX,
          tabY + i * tabStep,
          tab.width,
          tab.height,
        ),
      ),
    );
  }
  for (final (i, c) in shR.indexed) {
    out.add(
      PlacedControl(
        c,
        Rect.fromLTWH(
          w - safe.right - tabX - tab.width,
          tabY + i * tabStep,
          tab.width,
          tab.height,
        ),
      ),
    );
  }
  const gap = 10.0;
  final total = pills.length * _pillSize.width + (pills.length - 1) * gap;
  // Sideways the touch screen fills the bottom middle, so the pills move
  // under the shoulder tabs, the first half on the left.
  final besideTabs = !portrait && layout.touchScreen;
  final half = (pills.length + 1) ~/ 2;
  final besideTop = tabY + math.max(shL.length, shR.length) * tabStep;
  for (final (i, c) in pills.indexed) {
    double x, y;
    if (besideTabs) {
      final onLeft = i < half;
      x = onLeft ? safe.left + tabX : w - safe.right - tabX - _pillSize.width;
      y = besideTop + (onLeft ? i : i - half) * (_pillSize.height + gap);
    } else {
      x = w / 2 - total / 2 + i * (_pillSize.width + gap);
      y = pillY;
    }
    out.add(
      PlacedControl(c, Rect.fromLTWH(x, y, _pillSize.width, _pillSize.height)),
    );
  }
  for (final c in layout.controls) {
    if (c.cluster == TouchCluster.menu) {
      out.add(PlacedControl(c, circle(Offset(w / 2, menuY), c.size)));
    }
  }
  return out;
}

/// 8-way bits for a thumb offset from a d-pad centre: nothing inside
/// [deadZone], otherwise each axis past 22.5 degrees off the other.
int dpadBitsFor(Offset delta, double deadZone, List<int> ids) {
  if (delta.distance < deadZone) return 0;
  const diag = 0.3827; // sin 22.5 degrees
  final n = delta / delta.distance;
  var bits = 0;
  if (n.dy < -diag) bits |= _bit(ids[0]);
  if (n.dy > diag) bits |= _bit(ids[1]);
  if (n.dx < -diag) bits |= _bit(ids[2]);
  if (n.dx > diag) bits |= _bit(ids[3]);
  return bits;
}

/// A stick deflection as a unit-circle vector.
Offset stickVector(Offset delta, double radius) {
  final v = delta / radius;
  return v.distance > 1 ? v / v.distance : v;
}
