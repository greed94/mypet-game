import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'c3_theme.dart';
import 'pixel_icon.dart';

/// 화면 아래 종이 가장자리에 매달린 인덱스 탭 (3개까지). 아래 안전 영역 높이를 포함한다.
class IndexTabs extends StatelessWidget {
  const IndexTabs({
    super.key,
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onSelect,
    this.dots = const {},
  }) : assert(labels.length == icons.length && labels.length <= 3);

  final List<String> labels;
  final List<String> icons;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 새 소식이 있는 탭. 이름 옆에 빨간 점을 찍는다.
  final Set<int> dots;

  static const _height = 62.0;
  static const _gap = 10.0;
  static const _offColors = [
    (Color(0xFFF7E6B8), Color(0xFF6B5A34)),
    (Color(0xFFF5D3DA), Color(0xFF6E5258)),
    (Color(0xFFCFEBDA), Color(0xFF4A6B57)),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: _height + bottom,
      child: LayoutBuilder(
        builder: (context, box) {
          final n = labels.length;
          final w = math.min(136.0, (box.maxWidth - 24 - _gap * (n - 1)) / n);
          final start = (box.maxWidth - n * w - _gap * (n - 1)) / 2;
          double left(int i) => start + i * (w + _gap);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: ColoredBox(color: C3Colors.kraft)),
              for (var i = 0; i < n; i++)
                if (i != selected)
                  Positioned(
                    left: left(i),
                    top: 0,
                    width: w,
                    height: 52,
                    child: _tab(i),
                  ),
              // 페이지가 탭 띠 위에 드리우는 그림자. 선택 탭만 이 위로 올라온다.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(98, 72, 50, .16),
                        Color.fromRGBO(98, 72, 50, 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left(selected),
                top: -6,
                width: w,
                height: 66,
                child: _tab(selected),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tab(int i) {
    final on = i == selected;
    final (bg, fg) = on
        ? (C3Colors.paper, C3Colors.ink)
        : _offColors[i % _offColors.length];
    final text = Text(
      labels[i],
      maxLines: 1,
      style: TextStyle(
        fontFamily: C3Fonts.jua,
        fontFamilyFallback: C3Fonts.fallback,
        fontSize: on ? 18 : 17,
        height: 1.2,
        color: fg,
      ),
    );
    return Semantics(
      button: true,
      selected: on,
      label: dots.contains(i) ? '${labels[i]}, 새 글 있음' : labels[i],
      excludeSemantics: true,
      onTap: () => onSelect(i),
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: Container(
          padding: EdgeInsets.only(top: on ? 6 : 0),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(on ? 18 : 16),
            ),
            boxShadow: [
              on
                  ? const BoxShadow(
                      color: Color.fromRGBO(98, 72, 50, .20),
                      offset: Offset(0, 3),
                      blurRadius: 3.5,
                    )
                  : const BoxShadow(
                      color: Color.fromRGBO(98, 72, 50, .14),
                      offset: Offset(0, 2),
                      blurRadius: 1.7,
                    ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PixelIcon(icons[i]),
              const SizedBox(width: 7),
              if (on)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned(
                      left: -3,
                      right: -3,
                      bottom: -3,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: C3Colors.pinkLine,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                    text,
                  ],
                )
              else
                text,
              if (dots.contains(i)) ...[
                const SizedBox(width: 4),
                const SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: C3Colors.stamp,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
