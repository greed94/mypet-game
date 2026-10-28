import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'c3_theme.dart';
import 'pixel_icon.dart';

/// 보내기 우표. 우표만 -8° 기울고 발바닥은 똑바로. 누르면 도장처럼 눌린다.
class StampButton extends StatefulWidget {
  const StampButton({super.key, this.onTap, this.enabled = true});

  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<StampButton> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _press(bool down) {
    if (_active && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _active,
      label: '보내기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _active ? widget.onTap : null,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: Opacity(
          opacity: _active ? 1 : .5,
          child: AnimatedScale(
            scale: _down ? .9 : 1,
            duration: const Duration(milliseconds: 80),
            // 56px 줄에 넣어도 목업처럼 60px 우표가 가운데로 넘쳐 보이게 한다.
            child: SizedBox(
              width: 60,
              height: 60,
              child: OverflowBox(
                minWidth: 60,
                maxWidth: 60,
                minHeight: 60,
                maxHeight: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 2,
                      top: 2,
                      child: CustomPaint(
                        size: const Size(56, 56),
                        painter: _Stamp(pressed: _down),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      top: 12,
                      child: PixelIcon('paw', scale: 3),
                    ),
                    _speck(14, 41, 4),
                    _speck(43, 14, 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _speck(double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromRGBO(255, 244, 234, .7),
        ),
      ),
    );
  }
}

class _Stamp extends CustomPainter {
  const _Stamp({required this.pressed});

  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-s / 2, -s / 2);
    final edge = _perforated(s, 7, 2.6);
    canvas.drawPath(
      edge.shift(Offset(0, pressed ? .5 : 2)),
      Paint()..color = const Color.fromRGBO(98, 72, 50, .20),
    );
    canvas.drawPath(edge, Paint()..color = const Color(0xFFFFFDF8));
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color.fromRGBO(150, 118, 88, .35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, s - 10, s - 10),
        const Radius.circular(1.5),
      ),
      Paint()..color = C3Colors.stamp,
    );
    canvas.restore();
  }

  // c3 perfPath: 변마다 반원 구멍 n개가 안쪽으로 파인다.
  static Path _perforated(double s, int n, double r) {
    final p = s / n;
    final cs = [for (var i = 0; i < n; i++) p / 2 + i * p];
    final rad = Radius.circular(r);
    final path = Path()..moveTo(0, 0);
    for (final c in cs) {
      path
        ..lineTo(c - r, 0)
        ..arcToPoint(Offset(c + r, 0), radius: rad, clockwise: false);
    }
    path.lineTo(s, 0);
    for (final c in cs) {
      path
        ..lineTo(s, c - r)
        ..arcToPoint(Offset(s, c + r), radius: rad, clockwise: false);
    }
    path.lineTo(s, s);
    for (final c in cs.reversed) {
      path
        ..lineTo(c + r, s)
        ..arcToPoint(Offset(c - r, s), radius: rad, clockwise: false);
    }
    path.lineTo(0, s);
    for (final c in cs.reversed) {
      path
        ..lineTo(0, c + r)
        ..arcToPoint(Offset(0, c - r), radius: rad, clockwise: false);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_Stamp old) => old.pressed != pressed;
}
