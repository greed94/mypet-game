import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'c3_theme.dart';
import 'tape.dart';

/// c3 목업의 구름 몸통 크기. 이 크기일 때 목업과 똑같이 그려진다.
const cloudBodyReference = Size(233, 106);

/// 구름 몸통 안에서 글자가 들어갈 여백. body = 글자 크기 + 이 여백으로 잡으면 된다.
const cloudBodyPadding = EdgeInsets.fromLTRB(9, 28, 10, 30);

// c3.html #cloud 좌표. 몸통 외곽 상자는 x 9..242, y -1..105.
const _refLeft = 9.0;
const _refTop = -1.0;
const _puffs = [
  (46.0, 36.0, 22.0),
  (92.0, 26.0, 25.0),
  (146.0, 24.0, 25.0),
  (194.0, 32.0, 23.0),
  (224.0, 54.0, 18.0),
  (28.0, 62.0, 19.0),
  (70.0, 80.0, 21.0),
  (124.0, 86.0, 19.0),
  (178.0, 82.0, 21.0),
  (220.0, 70.0, 18.0),
];

final _aiLabel = TextPainter(
  text: const TextSpan(
    text: 'AI',
    style: TextStyle(
      fontFamily: C3Fonts.jua,
      fontFamilyFallback: C3Fonts.fallback,
      fontSize: 13,
      height: 1,
      color: Color(0xFF6A5646),
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// 속마음 구름을 [body] 크기에 맞춰 그리고, 아래로 [tailTip] 까지 작아지는 원 3개를 잇는다.
/// 글자는 그리지 않는다. Flame render 에서도 부르므로 BuildContext 에 기대지 않는다.
void paintThoughtCloud(
  Canvas canvas,
  Rect body,
  Offset tailTip, {
  bool aiTag = false,
}) {
  final sx = body.width / cloudBodyReference.width;
  final sy = body.height / cloudBodyReference.height;
  Offset at(double x, double y) =>
      Offset(body.left + (x - _refLeft) * sx, body.top + (y - _refTop) * sy);

  final shape = Path()
    ..addRRect(
      RRect.fromRectXY(
        Rect.fromPoints(at(14, 22), at(236, 82)),
        30 * sx,
        30 * sy,
      ),
    );
  for (final (x, y, r) in _puffs) {
    shape.addOval(
      Rect.fromCenter(center: at(x, y), width: 2 * r * sx, height: 2 * r * sy),
    );
  }

  final k = math.min(sx, sy);
  final anchor = Offset(
    (body.center.dx + (tailTip.dx - body.center.dx) * .5).clamp(
      body.left + body.width * .15,
      body.right - body.width * .15,
    ),
    body.bottom - 5 * sy,
  );
  for (final (t, r) in const [(.27, 8.0), (.64, 5.5), (1.0, 3.5)]) {
    shape.addOval(
      Rect.fromCircle(center: Offset.lerp(anchor, tailTip, t)!, radius: r * k),
    );
  }

  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint();

  // 겹친 원들의 반투명이 두 번 칠해지지 않게 불투명으로 그린 뒤 층째 흐리게 한다.
  final shadow = shape.shift(const Offset(0, 3));
  canvas.saveLayer(
    shadow.getBounds().inflate(4),
    Paint()..color = const Color.fromRGBO(0, 0, 0, .14),
  );
  const shadowColor = Color(0xFF624832);
  canvas.drawPath(shadow, fill..color = shadowColor);
  canvas.drawPath(shadow, stroke..color = shadowColor);
  canvas.restore();

  const outline = Color(0xFFD9C6AF);
  canvas.drawPath(shape, fill..color = outline);
  canvas.drawPath(shape, stroke..color = outline);
  canvas.drawPath(shape, fill..color = const Color(0xFFFFFFFF));

  if (aiTag) {
    final size = Size(_aiLabel.width + 18, 20);
    final c = at(196, -2) + Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(8 * math.pi / 180);
    canvas.translate(-size.width / 2, -size.height / 2);
    paintTape(canvas, size, const Color(0xFFFFF3C4), TapePattern.plain);
    _aiLabel.paint(canvas, Offset(9, (size.height - _aiLabel.height) / 2));
    canvas.restore();
  }
}
