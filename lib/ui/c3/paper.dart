import 'package:flutter/widgets.dart';

import 'c3_theme.dart';

/// 종이색 바탕에 18px 간격 점 격자.
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: const _DotGrid(), child: child);
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  static const _gap = 18.0;
  static const _first = 13.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = C3Colors.paper);
    final dot = Paint()..color = C3Colors.dot;
    for (var y = _first; y < size.height; y += _gap) {
      for (var x = _first; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid oldDelegate) => false;
}
