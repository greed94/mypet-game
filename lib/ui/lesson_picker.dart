import 'package:flutter/material.dart';

import '../pet/tricks.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';

/// 맡길 때 고른 오늘 수업. [trick]이 null이면 자유 놀이.
class LessonChoice {
  const LessonChoice(this.trick);

  final Trick? trick;
}

/// 오늘 수업 고르기. 닫으면 null(맡기지 않음).
Future<LessonChoice?> showLessonPicker(
  BuildContext context,
  Map<Trick, TrickProgress> tricks,
) {
  return showDialog<LessonChoice>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StickerCard(
        tape: C3Colors.tapeYellow,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
        child: LessonPicker(
          tricks: tricks,
          onPick: (c) => Navigator.of(context).pop(c),
        ),
      ),
    ),
  );
}

class LessonPicker extends StatelessWidget {
  const LessonPicker({super.key, required this.tricks, required this.onPick});

  final Map<Trick, TrickProgress> tricks;
  final ValueChanged<LessonChoice> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('오늘 수업', style: C3Text.title),
        const SizedBox(height: 6),
        Text(
          keepWords('두 시간 넘게 있으면 하루 한 번 연습해 와요. 배운 건 복습이라 별이 늘어요.'),
          style: C3Text.body.copyWith(color: C3Colors.ink2),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in Trick.values)
              if (t.chip)
                ActionChip(
                  label: Text(
                    (tricks[t]?.learned ?? false) ? '${t.label} · 복습' : t.label,
                  ),
                  onPressed: () => onPick(LessonChoice(t)),
                ),
            ActionChip(
              label: const Text('자유 놀이'),
              onPressed: () => onPick(const LessonChoice(null)),
            ),
          ],
        ),
      ],
    );
  }
}
