import 'package:flutter/material.dart';

import '../pet/spots.dart';
import 'c3/c3_theme.dart';
import 'c3/pixel_icon.dart';
import 'c3/sticker_card.dart';

/// 문을 열면 뜨는 동네 지도. 고른 장소를 돌려주고, 닫으면 null.
/// [wish]는 오늘 펫이 가고 싶어 하는 곳(작은 하트로 표시).
Future<Spot?> showTownMap(BuildContext context, {Spot? wish}) {
  return showDialog<Spot>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: StickerCard(
          tape: C3Colors.tapeMint,
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('어디 갈까?', style: C3Text.title)),
                  Semantics(
                    container: true,
                    button: true,
                    label: '지도 닫기',
                    excludeSemantics: true,
                    onTap: () => Navigator.of(context).pop(),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      excludeFromSemantics: true,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Center(child: PixelIcon('close', scale: 2)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 짧은 화면에서도 장소를 줄여 누르기 어렵게 만들지 않는다.
              Flexible(
                child: SingleChildScrollView(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: TownMap(
                      wish: wish,
                      onPick: (s) => Navigator.of(context).pop(s),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 지도 그림 위에 장소 이름표를 얹는다. 건물을 누르는 느낌이 나게 누르는 자리는 이름표 위 건물까지 넓다.
class TownMap extends StatelessWidget {
  const TownMap({super.key, required this.onPick, this.wish});

  final ValueChanged<Spot> onPick;

  /// 오늘 펫이 가고 싶어 하는 곳. 이름표 위에 작은 하트를 띄운다.
  final Spot? wish;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final boxW = w * spotTapWidth, boxH = h * spotTapHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/art/town_map.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              for (final s in Spot.values)
                Positioned(
                  left: w * s.x - boxW / 2,
                  top: h * s.y + 16 - boxH,
                  width: boxW,
                  height: boxH,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: '${s.label}에 가기',
                    onTap: () => onPick(s),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => onPick(s),
                      excludeFromSemantics: true,
                      behavior: HitTestBehavior.opaque,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _Tag(spot: s),
                      ),
                    ),
                  ),
                ),
              // 누르는 칸 위에 얹되 탭은 그대로 칸이 받는다.
              if (wish case final s?)
                Positioned(
                  left: w * s.x - 17,
                  top: h * s.y - 40,
                  child: const IgnorePointer(child: _WishMark()),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 가고 싶어 하는 곳 표시. 말 없는 생각 풍선에 하트 하나.
class _WishMark extends StatelessWidget {
  const _WishMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '오늘 가고 싶어 하는 곳',
      child: Container(
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C3Colors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: C3Colors.stamp, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: C3Colors.shadow,
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: const PixelIcon('heart', scale: 2),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 4),
      decoration: BoxDecoration(
        color: C3Colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C3Colors.line, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: C3Colors.shadow,
            offset: Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          spot.label,
          maxLines: 1,
          softWrap: false,
          style: C3Text.label,
        ),
      ),
    );
  }
}
