import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:moonfin_design/moonfin_design.dart';

/// The frame around Harbor's corner trailer: worn brass with rivets, a strip
/// of film draped over one corner and a short end hanging from the top, a
/// touch of grain and vignette on the picture. Kept quiet so the trailer
/// stays the thing to look at.
class HarborTrailerFrame extends StatelessWidget {
  const HarborTrailerFrame({super.key, required this.child});

  final Widget child;

  static const _radius = 10.0;
  static const _border = 5.0;

  @override
  Widget build(BuildContext context) {
    final brass = AppColorScheme.accent;
    final light = Color.lerp(brass, Colors.white, 0.35)!;
    final dark = Color.lerp(brass, Colors.black, 0.55)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, frame) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.96 + 0.04 * t, child: frame),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final strip = (w * 0.075).clamp(18.0, 44.0);
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Worn brass rim.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [light, brass, dark, brass, light],
                    stops: const [0, 0.25, 0.55, 0.8, 1],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(_border),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius - _border / 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.black),
                      child,
                      const IgnorePointer(child: _Vignette()),
                      const IgnorePointer(
                        child: CustomPaint(painter: _GrainPainter()),
                      ),
                    ],
                  ),
                ),
              ),
              // Rivets in the corners.
              for (final a in const [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: a,
                  child: Padding(
                    padding: const EdgeInsets.all(_border * 0.1),
                    child: _Rivet(light: light, dark: dark),
                  ),
                ),
              // Film draped over the top-left corner.
              Positioned(
                left: -strip * 1.1,
                top: strip * 0.9,
                width: strip * 4.6,
                height: strip,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: _FilmStrip(frames: 3),
                ),
              ),
              // A short end of film hanging from the top edge.
              Positioned(
                right: w * 0.16,
                top: -strip * 0.55,
                width: strip,
                height: strip * 2.4,
                child: Transform.rotate(
                  angle: 0.10,
                  alignment: Alignment.topCenter,
                  child: const _FilmStrip(frames: 2, vertical: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  const _Rivet({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [light, dark],
      ),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
    ),
  );
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        radius: 0.95,
        colors: [Color(0x00000000), Color(0x00000000), Color(0x59000000)],
        stops: [0, 0.6, 1],
      ),
    ),
  );
}

/// A fixed sprinkle of light and dark specks: film grain without the cost of
/// animating it.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final light = Paint()..color = const Color(0x14FFFFFF);
    final dark = Paint()..color = const Color(0x1A000000);
    final count = (size.width * size.height / 900).clamp(0, 900).toInt();
    for (var i = 0; i < count; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      canvas.drawCircle(
        o,
        rnd.nextDouble() * 0.9 + 0.3,
        i.isEven ? light : dark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}

/// A piece of 35 mm film: dark celluloid, sprocket holes on both edges and
/// faint frames between them.
class _FilmStrip extends StatelessWidget {
  const _FilmStrip({required this.frames, this.vertical = false});

  final int frames;
  final bool vertical;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FilmStripPainter(
      frames: frames,
      vertical: vertical,
      tint: AppColorScheme.accent,
    ),
  );
}

class _FilmStripPainter extends CustomPainter {
  _FilmStripPainter({
    required this.frames,
    required this.vertical,
    required this.tint,
  });

  final int frames;
  final bool vertical;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (vertical) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      _paint(canvas, Size(size.height, size.width));
      canvas.restore();
    } else {
      _paint(canvas, size);
    }
  }

  void _paint(Canvas canvas, Size size) {
    final len = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(h * 0.08),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 4, false);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xF21B1712),
            Color.lerp(const Color(0xF22A231A), tint, 0.08)!,
            const Color(0xF21B1712),
          ],
        ).createShader(Offset.zero & size),
    );
    // Sprocket holes along both edges.
    final hole = Paint()..color = const Color(0xCCE9DFC8);
    final holeW = h * 0.13, holeH = h * 0.11, edge = h * 0.07;
    final pitch = holeW * 2.1;
    for (var x = pitch * 0.4; x < len - holeW; x += pitch) {
      for (final y in [edge, h - edge - holeH]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, holeW, holeH),
            Radius.circular(holeH * 0.3),
          ),
          hole,
        );
      }
    }
    // Faint frames in the middle band.
    final band = Rect.fromLTRB(0, h * 0.26, len, h * 0.74);
    final frameW = len / frames;
    final framePaint = Paint()
      ..color = tint.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..color = tint.withValues(alpha: 0.06);
    for (var i = 0; i < frames; i++) {
      final r = Rect.fromLTWH(
        i * frameW + frameW * 0.08,
        band.top,
        frameW * 0.84,
        band.height,
      );
      final rr = RRect.fromRectAndRadius(r, Radius.circular(h * 0.04));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, framePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmStripPainter old) =>
      old.frames != frames || old.vertical != vertical || old.tint != tint;
}
