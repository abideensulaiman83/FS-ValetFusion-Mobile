// lib/components/damage/car_diagram.dart
//
// Top view of a car, drawn with the same 340 x 500 geometry as the portal's CarDiagram SVG
// (frontend DashboardPage.tsx) - front bumper at the top, driver's side on the left - so a mark
// at (x%, y%) sits on the same panel in the app and on the web. Marks are numbered dots coloured
// by damage type; tapping the car reports the spot (and the panel under it) to [onTap].
// The drawing is never mirrored in right-to-left layouts (its left is the car's left); only the
// zone labels are translated. Panel names stay English in data (see diagramPartAt) and are
// translated where they are shown.
import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../services/damage_service.dart';
import '../../theme/app_theme.dart';

const double kDiagramW = 340;
const double kDiagramH = 500;

Color damageTypeColor(DamageType t, Brightness b) {
  final vf = VfColors.of(b);
  return switch (t) {
    DamageType.scratch => vf.warning,
    DamageType.dent => vf.danger,
    DamageType.crack => vf.live,
    DamageType.other => vf.brass,
  };
}

class _Part {
  final String label;
  final Path path;
  final List<Rect> windows; // door glass drawn inside the panel
  const _Part(this.label, this.path, [this.windows = const []]);
}

Path _poly(List<double> p) {
  final path = Path()..moveTo(p[0], p[1]);
  for (var i = 2; i < p.length; i += 2) {
    path.lineTo(p[i], p[i + 1]);
  }
  return path..close();
}

Path _oval(double cx, double cy, double rx, double ry) => Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

// Same ids/coordinates as the portal diagram.
final List<_Part> _parts = [
  _Part('Front bumper', _poly([106, 14, 234, 14, 244, 30, 96, 30])),
  _Part('Front left wing', _poly([70, 32, 100, 32, 100, 62, 82, 132, 54, 132])),
  _Part('Front left wheel', _oval(40, 130, 24, 24)),
  _Part('Front right wing', _poly([270, 32, 240, 32, 240, 62, 258, 132, 286, 132])),
  _Part('Front right wheel', _oval(300, 130, 24, 24)),
  _Part('Bonnet', _poly([108, 32, 232, 32, 224, 145, 116, 145])),
  _Part('Left headlight', _poly([100, 32, 116, 32, 108, 145, 92, 145, 84, 132, 84, 62, 100, 62])),
  _Part('Right headlight', _poly([240, 32, 224, 32, 232, 145, 248, 145, 256, 132, 256, 62, 240, 62])),
  _Part('Windscreen', _poly([108, 148, 232, 148, 226, 196, 114, 196])),
  _Part('Front left door', _poly([54, 135, 86, 135, 88, 148, 88, 198, 86, 202, 54, 202]), [const Rect.fromLTWH(59, 140, 26, 38)]),
  _Part('Front right door', _poly([286, 135, 254, 135, 252, 148, 252, 198, 254, 202, 286, 202]), [const Rect.fromLTWH(255, 140, 26, 38)]),
  _Part('Roof', Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(108, 199, 124, 86), const Radius.circular(2)))),
  _Part('Rear left door', _poly([54, 205, 86, 205, 88, 210, 88, 288, 86, 292, 54, 292]), [const Rect.fromLTWH(59, 212, 26, 56)]),
  _Part('Rear right door', _poly([286, 205, 254, 205, 252, 210, 252, 288, 254, 292, 286, 292]), [const Rect.fromLTWH(255, 212, 26, 56)]),
  _Part('Rear left wing', _poly([54, 295, 82, 295, 100, 368, 100, 390, 70, 390, 54, 374])),
  _Part('Rear left wheel', _oval(40, 368, 24, 24)),
  _Part('Rear right wing', _poly([286, 295, 258, 295, 240, 368, 240, 390, 270, 390, 286, 374])),
  _Part('Rear right wheel', _oval(300, 368, 24, 24)),
  _Part('Rear window', _poly([108, 288, 232, 288, 226, 322, 114, 322])),
  _Part('Boot', _poly([116, 325, 146, 325, 146, 393, 116, 393])),
  _Part('Boot (spare / kit)', _oval(196, 362, 44, 38)),
  _Part('Rear bumper', Path()
    ..addPath(_poly([96, 396, 244, 396, 234, 412, 106, 412]), Offset.zero)
    ..addPath(_poly([106, 414, 234, 414, 226, 426, 114, 426]), Offset.zero)),
];

const List<(String, double, double)> _labels = [
  ('FRONT', 170, 6),
  ('BONNET', 170, 90),
  ('WINDSCREEN', 170, 172),
  ('ROOF', 170, 242),
  ('WINDOW', 170, 305),
  ('BUMPER', 170, 438),
  ('REAR', 170, 456),
];

/// The panel under a diagram point (in 340 x 500 units), e.g. "Bonnet"; null off the car.
/// Returns the English name (it can end up in saved data) - show it with tr(context, part).
String? diagramPartAt(Offset p) {
  for (final part in _parts.reversed) {
    if (part.path.contains(p)) return part.label;
  }
  return null;
}

class CarDiagram extends StatelessWidget {
  final List<DamageMark> marks;

  /// Tap position as percentages of the diagram, plus the panel under it (null when off the car).
  final void Function(double xPct, double yPct, String? part)? onTap;
  final void Function(int index)? onMarkTap;
  final bool dimmed;

  const CarDiagram({super.key, required this.marks, this.onTap, this.onMarkTap, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final labels = [for (final (text, x, y) in _labels) (tr(context, text), x, y)];
    final dir = Directionality.of(context);
    return AspectRatio(
      aspectRatio: kDiagramW / kDiagramH,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onTap == null
                    ? null
                    : (d) {
                        final x = (d.localPosition.dx / w).clamp(0.0, 1.0);
                        final y = (d.localPosition.dy / h).clamp(0.0, 1.0);
                        onTap!(x * 100, y * 100, diagramPartAt(Offset(x * kDiagramW, y * kDiagramH)));
                      },
                child: Opacity(
                  opacity: dimmed ? 0.45 : 1,
                  child: CustomPaint(painter: _CarPainter(b, labels, dir)),
                ),
              ),
            ),
            // Physical position on the car - deliberately not directional.
            for (var i = 0; i < marks.length; i++)
              Positioned(
                left: marks[i].xPct / 100 * w - 12,
                top: marks[i].yPct / 100 * h - 12,
                child: GestureDetector(
                  onTap: onMarkTap == null ? null : () => onMarkTap!(i),
                  child: DamageMarkDot(number: i + 1, mark: marks[i]),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Numbered dot in the damage type's colour; a ring marks one not saved yet.
class DamageMarkDot extends StatelessWidget {
  final int number;
  final DamageMark mark;
  final double size;
  const DamageMarkDot({super.key, required this.number, required this.mark, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final color = damageTypeColor(mark.type, Theme.of(context).brightness);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: mark.saved ? context.vf.card : context.vf.textPrimary, width: mark.saved ? 2 : 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Text('$number', style: AppTheme.numeral(size: size * 0.55, color: AppTheme.contrastOn(color))),
    );
  }
}

class _CarPainter extends CustomPainter {
  final Brightness brightness;
  final List<(String, double, double)> labels;
  final TextDirection textDirection;
  _CarPainter(this.brightness, this.labels, this.textDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final vf = VfColors.of(brightness);
    canvas.save();
    canvas.scale(size.width / kDiagramW, size.height / kDiagramH);

    final fill = Paint()..color = vf.card2;
    final stroke = Paint()
      ..color = vf.textSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final thin = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (final part in _parts) {
      canvas.drawPath(part.path, fill);
      canvas.drawPath(part.path, stroke);
      for (final r in part.windows) {
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1)), thin);
      }
    }
    // Wheel hubs and the spare-wheel well, as on the portal.
    for (final c in const [Offset(40, 130), Offset(300, 130), Offset(40, 368), Offset(300, 368)]) {
      canvas.drawCircle(c, 14, thin);
    }
    canvas.drawOval(Rect.fromCenter(center: const Offset(196, 362), width: 64, height: 56), thin);
    // Number plates.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(130, 15, 80, 14), const Radius.circular(2)), thin);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(122, 398, 96, 11), const Radius.circular(1.5)), thin);

    final textColor = vf.textSecondary;
    for (final (text, x, y) in labels) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.6)),
        textDirection: textDirection,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) =>
      old.brightness != brightness || old.textDirection != textDirection || !_sameLabels(old.labels, labels);

  static bool _sameLabels(List<(String, double, double)> a, List<(String, double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
