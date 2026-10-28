import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'c3_theme.dart';
import 'pixel_icon.dart';

/// 상태 스티커. 원과 아이콘은 똑바로, 차오른 물의 윗면만 [tilt]도 기운다.
class GaugeSticker extends StatelessWidget {
  const GaugeSticker({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.tilt = 0,
  });

  final String icon;
  final String label;
  final int value;
  final GaugeColors colors;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFFFFF),
            boxShadow: [
              BoxShadow(
                color: C3Colors.shadow,
                offset: Offset(0, 2),
                blurRadius: 2.6,
              ),
            ],
          ),
          child: ClipOval(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0, 100) / 100),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) =>
                  CustomPaint(painter: _Water(v, colors, tilt), child: child),
              child: Center(child: PixelIcon(icon)),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            text: '$label ',
            children: [
              const WidgetSpan(child: SizedBox(width: 2)),
              TextSpan(
                text: '$value',
                style: TextStyle(color: colors.tone),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            fontFamily: C3Fonts.jua,
            fontFamilyFallback: C3Fonts.fallback,
            fontSize: 15,
            height: 18 / 15,
            leadingDistribution: TextLeadingDistribution.even,
            color: C3Colors.ink,
          ),
        ),
      ],
    );
  }
}

class _Water extends CustomPainter {
  const _Water(this.level, this.colors, this.tilt);

  final double level;
  final GaugeColors colors;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.bg);
    // c3: 72×64 물 상자를 윗변 가운데를 축으로 돌린다 (44px 원 기준 비율).
    final halfW = size.width * 36 / 44;
    canvas.save();
    canvas.translate(size.width / 2, size.height * (1 - level));
    canvas.rotate(tilt * math.pi / 180);
    canvas.drawRect(
      Rect.fromLTWH(-halfW, 0, halfW * 2, size.height * 64 / 44),
      Paint()..color = colors.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(-halfW, 0, halfW * 2, 2),
      Paint()..color = const Color.fromRGBO(255, 255, 255, .85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Water old) =>
      old.level != level || old.colors != colors || old.tilt != tilt;
}
