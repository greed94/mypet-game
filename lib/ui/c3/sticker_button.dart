import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'c3_theme.dart';
import 'pixel_icon.dart';
import 'tape.dart';

/// 행동 버튼. 흰 다이컷 스티커만 [tilt]도 기울고 아이콘은 똑바로 선다.
/// [onTap] 이 null 이면 비활성, [highlighted] 면 노란 테이프와 반짝이로 조른다.
class StickerButton extends StatefulWidget {
  const StickerButton({
    super.key,
    required this.cut,
    required this.icon,
    required this.label,
    this.tilt = 0,
    this.onTap,
    this.highlighted = false,
    this.width = 104,
    this.compact = false,
  });

  final String cut;
  final String icon;
  final String label;
  final double tilt;
  final VoidCallback? onTap;
  final bool highlighted;

  /// 한 줄에 넷이 설 땐 좁힌다(폰 폭 360dp).
  final double width;
  final bool compact;

  @override
  State<StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<StickerButton> {
  bool _down = false;

  void _press(bool down) {
    if (widget.onTap != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final labelHeight = MediaQuery.textScalerOf(context).scale(16) * 18 / 16;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: AnimatedScale(
            scale: _down ? .94 : 1,
            duration: const Duration(milliseconds: 90),
            child: SizedBox(
              width: widget.width,
              height: widget.compact ? 48 : 70 + math.max(18, labelHeight),
              child: widget.compact
                  ? _compactButton()
                  : Column(
                      children: [
                        const SizedBox(height: 2),
                        _sticker(),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            style: C3Text.label,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactButton() {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.highlighted ? C3Colors.tapeYellow : C3Colors.card,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: C3Colors.shadow, offset: Offset(0, 1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelIcon(widget.icon, scale: 1),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  widget.label,
                  style: C3Text.label.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sticker() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.highlighted)
            const Positioned(
              left: -12,
              top: 24,
              child: Tape(
                width: 88,
                height: 24,
                color: C3Colors.tapeYellow,
                angle: -18,
              ),
            ),
          Transform.rotate(
            angle: widget.tilt * math.pi / 180,
            child: Stack(
              children: [
                _silhouette(
                  const Color.fromRGBO(98, 72, 50, .10),
                  const Offset(0, 3.2),
                ),
                _silhouette(
                  const Color.fromRGBO(98, 72, 50, .14),
                  const Offset(0, 1.6),
                ),
                // 0.4칸 가장자리 선: 실루엣을 사방 0.8px 밀어 겹친 뒤 한 번에 흐리게.
                Opacity(
                  opacity: .4,
                  child: Stack(
                    children: [
                      for (final o in _around)
                        _silhouette(const Color(0xFF967658), o),
                    ],
                  ),
                ),
                _silhouette(null, Offset.zero),
              ],
            ),
          ),
          Positioned(left: 8, top: 8, child: PixelIcon(widget.icon, scale: 4)),
          if (widget.highlighted)
            const Positioned(right: -10, top: -8, child: PixelIcon('sparkle')),
        ],
      ),
    );
  }

  static const _around = [
    Offset(.8, 0),
    Offset(-.8, 0),
    Offset(0, .8),
    Offset(0, -.8),
    Offset(.57, .57),
    Offset(-.57, .57),
    Offset(.57, -.57),
    Offset(-.57, -.57),
  ];

  Widget _silhouette(Color? tint, Offset offset) {
    return Transform.translate(
      offset: offset,
      child: Image.asset(
        'assets/ui/cut_${widget.cut}.png',
        width: 64,
        height: 64,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.srcIn,
        gaplessPlayback: true,
      ),
    );
  }
}
