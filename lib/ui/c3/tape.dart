import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum TapePattern { stripes, dots, plain }

/// 마스킹 테이프. 테이프만 [angle]도 기울고 [child](글자 등)는 똑바로 선다.
/// 크기는 [width]·[height] 가 없으면 [child] 를 따른다.
class Tape extends StatelessWidget {
  const Tape({
    super.key,
    this.width,
    this.height,
    required this.color,
    this.angle = 0,
    this.pattern = TapePattern.stripes,
    this.child,
  });

  final double? width;
  final double? height;
  final Color color;
  final double angle;
  final TapePattern pattern;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TapePainter(color, angle, pattern),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

/// 캔버스 원점부터 [size] 크기로 테이프를 그린다. 회전은 호출하는 쪽이 한다.
void paintTape(Canvas canvas, Size size, Color color, TapePattern pattern) {
  canvas.save();
  canvas.clipPath(_tapePath(size));
  canvas.drawRect(Offset.zero & size, Paint()..color = color);
  switch (pattern) {
    case TapePattern.stripes:
      final p = Paint()..color = const Color.fromRGBO(255, 255, 255, .32);
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 3, size.height), p);
      }
    case TapePattern.dots:
      final p = Paint()..color = const Color.fromRGBO(255, 255, 255, .55);
      for (var y = 4.5; y < size.height + 2; y += 9) {
        for (var x = 4.5; x < size.width + 2; x += 9) {
          canvas.drawCircle(Offset(x, y), 1.8, p);
        }
      }
    case TapePattern.plain:
      break;
  }
  canvas.restore();
}

// c3 .tape 의 clip-path: 양 끝이 4px 깊이 톱니.
Path _tapePath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(4, 0)
    ..lineTo(w - 4, 0)
    ..lineTo(w, h * .17)
    ..lineTo(w - 4, h * .33)
    ..lineTo(w, h * .5)
    ..lineTo(w - 4, h * .67)
    ..lineTo(w, h * .83)
    ..lineTo(w - 4, h)
    ..lineTo(4, h)
    ..lineTo(0, h * .83)
    ..lineTo(4, h * .67)
    ..lineTo(0, h * .5)
    ..lineTo(4, h * .33)
    ..lineTo(0, h * .17)
    ..close();
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.color, this.angle, this.pattern);

  final Color color;
  final double angle;
  final TapePattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    paintTape(canvas, size, color, pattern);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TapePainter old) =>
      old.color != color || old.angle != angle || old.pattern != pattern;
}
