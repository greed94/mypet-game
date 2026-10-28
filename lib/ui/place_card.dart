import 'package:flutter/material.dart';

import 'c3/c3_theme.dart';
import 'c3/pixel_icon.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';

/// 장소에 있는 동안 홈 화면 아래에 뜨는 카드. 왼쪽 그림, 가운데 두 줄, 오른쪽 버튼.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.tape,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final Color tape;
  final String icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: StickerCard(
        tape: tape,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
        child: Row(
          children: [
            PixelIcon(icon, scale: 3),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: C3Text.label),
                  const SizedBox(height: 2),
                  Text(
                    keepWords(subtitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: C3Text.body.copyWith(color: C3Colors.ink2),
                  ),
                ],
              ),
            ),
            for (final (i, a) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              a,
            ],
          ],
        ),
      ),
    );
  }
}

/// 장소 카드처럼 버튼 둘이 한 줄에 서는 곳에서 쓴다.
final compactButton = ButtonStyle(
  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14)),
);
