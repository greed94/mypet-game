import 'package:flutter/material.dart';

import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import '../pet/tricks.dart';
import '../services/telemetry.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';

/// 훈련 수첩. 개인기마다 별과 배운 날, 다음 별을 받는 법, 발표회 도장 수.
Future<void> showTrickNotebook(BuildContext context, PetController c) {
  Telemetry.track('notebook_open', {
    'learned': c.tricks.values.where((p) => p.learned).length,
  });
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: StickerCard(
        tape: C3Colors.tapeMint,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => TrickNotebook(
            petName: c.pet.name,
            tricks: c.tricks,
            today: dayKey(petDate(c.now())),
            stamps: c.recitalStamps.length,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ),
  );
}

class TrickNotebook extends StatelessWidget {
  const TrickNotebook({
    super.key,
    required this.petName,
    required this.tricks,
    required this.today,
    required this.stamps,
    required this.onClose,
  });

  final String petName;
  final Map<Trick, TrickProgress> tricks;
  final String today;
  final int stamps;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$petName의 훈련 수첩', style: C3Text.title),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final t in Trick.values)
                  _Row(
                    trick: t,
                    progress: tricks[t] ?? const TrickProgress(),
                    today: today,
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 18),
        Text(
          stamps == 0
              ? '금요일에 유치원에 가면 발표회에서 도장을 받아요'
              : '발표회 도장 $stamps개 · 금요일 유치원에서',
          textAlign: TextAlign.center,
          style: C3Text.body.copyWith(fontSize: 13, color: C3Colors.ink2),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onClose, child: const Text('닫기')),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.trick,
    required this.progress,
    required this.today,
  });

  final Trick trick;
  final TrickProgress progress;
  final String today;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final mark = p.learned
        ? '★' * p.stars + '☆' * (3 - p.stars)
        : p.attempts > 0
        ? '배우는 중'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(trick.label, style: C3Text.label)),
              Text(
                mark,
                style: C3Text.label.copyWith(
                  fontSize: 14,
                  color: p.learned ? C3Colors.stamp : C3Colors.hint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            keepWords(notebookLine(trick, p, today: today)),
            style: C3Text.body.copyWith(fontSize: 12.5, color: C3Colors.ink3),
          ),
        ],
      ),
    );
  }
}
