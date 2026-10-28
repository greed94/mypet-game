import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../pet/walk_log.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';

/// 산책이 끝나면 뜨는 산책 지도. 위치를 재지 않아 길은 그날의 낙서이고, 킁킁 자리가 발자국으로 찍힌다.
Future<void> showWalkCard(
  BuildContext context, {
  required String name,
  required DateTime startedAt,
  required int minutes,
  required int steps,
  required int finds,
  required List<WalkSpot> spots,
}) => showC3Dialog<void>(
  context,
  title: '$name의 산책 지도',
  body: WalkMap(
    startedAt: startedAt,
    spots: spots,
    summary: [
      '$minutes분',
      if (steps > 0) '${_thousands(steps)}걸음',
      if (finds > 0) '뭔가 물고 왔어요',
    ].join(' · '),
  ),
);

String _thousands(int n) => n < 1000
    ? '$n'
    : '${_thousands(n ~/ 1000)},${(n % 1000).toString().padLeft(3, '0')}';

class WalkMap extends StatelessWidget {
  const WalkMap({
    super.key,
    required this.startedAt,
    required this.spots,
    required this.summary,
  });

  final DateTime startedAt;
  final List<WalkSpot> spots;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: CustomPaint(painter: _MapPainter(walkPath(startedAt), spots)),
        ),
        const SizedBox(height: 10),
        Text(summary, style: C3Text.body.copyWith(color: C3Colors.ink2)),
        if (spots.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${spots.map((s) => s.name).join(', ')}에서 오래 킁킁댔어요',
            style: C3Text.body.copyWith(fontSize: 14, color: C3Colors.ink2),
          ),
        ],
        if (spots.isEmpty)
          Text(
            '오늘은 킁킁할 새 없이 바빴어요',
            style: C3Text.body.copyWith(fontSize: 14, color: C3Colors.ink3),
          ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.path, this.spots);

  final List<(double, double)> path;
  final List<WalkSpot> spots;

  static const _paper = Color(0xFFF4EEDF);
  static const _block = Color(0xFFE6DCC6);
  static const _road = Color(0xFF9C8A79);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = _paper,
    );
    // 동네 블록. 지도처럼 보이게 하는 배경일 뿐이라 늘 같은 자리다.
    final block = Paint()..color = _block;
    for (final (x, y, w, h) in const [
      (0.06, 0.08, 0.22, 0.2),
      (0.36, 0.06, 0.18, 0.16),
      (0.66, 0.1, 0.26, 0.18),
      (0.1, 0.72, 0.2, 0.18),
      (0.44, 0.76, 0.24, 0.16),
      (0.76, 0.7, 0.18, 0.22),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x * size.width,
            y * size.height,
            w * size.width,
            h * size.height,
          ),
          const Radius.circular(4),
        ),
        block,
      );
    }
    const pad = 22.0;
    Offset at((double, double) p) => Offset(
      pad + p.$1 * (size.width - pad * 2),
      pad + p.$2 * (size.height - pad * 2),
    );
    final points = [for (final p in path) at(p)];
    // 점선 길.
    final road = Paint()
      ..color = _road
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i], b = points[i + 1];
      final d = (b - a).distance;
      for (var t = 0.0; t < d; t += 9) {
        final u = t / d, v = min(1.0, (t + 5) / d);
        canvas.drawLine(Offset.lerp(a, b, u)!, Offset.lerp(a, b, v)!, road);
      }
    }
    _house(canvas, points.first);
    _house(canvas, points.last);
    final paw = Paint()..color = C3Colors.stamp;
    for (final (i, s) in spots.indexed) {
      final p = _along(points, s.at.clamp(0.05, 0.95));
      canvas.drawCircle(p, 7, paw);
      for (final (dx, dy) in const [(-6.0, -8.0), (0.0, -10.0), (6.0, -8.0)]) {
        canvas.drawCircle(p + Offset(dx, dy), 2.4, paw);
      }
      _label(canvas, s.name, p, size, above: i.isEven);
    }
  }

  void _house(Canvas canvas, Offset p) {
    final fill = Paint()..color = C3Colors.ink2;
    canvas.drawRect(Rect.fromCenter(center: p, width: 12, height: 9), fill);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 9, p.dy - 4)
        ..lineTo(p.dx, p.dy - 12)
        ..lineTo(p.dx + 9, p.dy - 4)
        ..close(),
      fill,
    );
  }

  /// 길 위 [t](0~1)만큼 간 곳. 길이로 나눈다.
  Offset _along(List<Offset> pts, double t) {
    final lengths = [
      for (var i = 0; i + 1 < pts.length; i++) (pts[i + 1] - pts[i]).distance,
    ];
    var left = t * lengths.fold(0.0, (a, b) => a + b);
    for (var i = 0; i < lengths.length; i++) {
      if (left <= lengths[i]) {
        return Offset.lerp(pts[i], pts[i + 1], left / lengths[i])!;
      }
      left -= lengths[i];
    }
    return pts.last;
  }

  void _label(
    Canvas canvas,
    String text,
    Offset p,
    Size size, {
    required bool above,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: C3Text.body.copyWith(fontSize: 12, color: C3Colors.ink),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.5);
    final x = (p.dx - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
    final y = above ? p.dy - 16 - tp.height : p.dy + 10;
    tp.paint(canvas, Offset(x, y.clamp(2.0, size.height - tp.height - 2)));
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.path != path || old.spots != spots;
}
