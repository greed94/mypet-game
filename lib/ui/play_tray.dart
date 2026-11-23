import 'package:flutter/material.dart';

import '../pet/tricks.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';

/// 놀아 주는 동안 행동 줄 자리에 뜬다. 개인기는 칩이나 말로 시키고, 공은 방에서 위로 쓸어 올려 던진다.
class PlayTray extends StatelessWidget {
  const PlayTray({
    super.key,
    required this.tricks,
    required this.onTrick,
    required this.onClose,
    this.hide = const {},
    this.onNotebook,
    this.onThrow,
    this.compact = false,
    this.treats = 0,
    this.onTreat,
  });

  final Map<Trick, TrickProgress> tricks;

  /// 훈련 수첩 열기. '수첩' 버튼과 칩 길게 누르기.
  final VoidCallback? onNotebook;

  /// 여기선 못 하는 개인기(카페의 '물어와').
  final Set<Trick> hide;
  final ValueChanged<Trick> onTrick;
  final VoidCallback onClose;
  final VoidCallback? onThrow;
  final bool compact;

  /// 주머니 간식 수. 개인기를 해낸 직후 주면 칭찬이 된다(놀이 칸이 밥·간식 줄을 가려서 여기에도 둔다).
  final int treats;
  final VoidCallback? onTreat;

  @override
  Widget build(BuildContext context) {
    final tray = Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 14, 16, 2),
      child: StickerCard(
        tape: C3Colors.tapeSky,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onThrow != null)
                TextButton.icon(
                  onPressed: onThrow,
                  icon: const Icon(Icons.sports_baseball_outlined, size: 18),
                  label: const Text('공 던지기'),
                ),
              for (final t in Trick.values)
                if (t.chip && !hide.contains(t))
                  _TrickChip(
                    trick: t,
                    progress: tricks[t],
                    onTap: () => onTrick(t),
                    onLongPress: onNotebook,
                  ),
              if (treats > 0 && onTreat != null)
                TextButton(
                  onPressed: onTreat,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text('간식 $treats'),
                ),
              if (onNotebook != null)
                TextButton(
                  onPressed: onNotebook,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('훈련 수첩'),
                ),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('그만 놀기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!compact) return tray;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 88),
      child: SingleChildScrollView(child: tray),
    );
  }
}

class _TrickChip extends StatelessWidget {
  const _TrickChip({
    required this.trick,
    required this.progress,
    required this.onTap,
    this.onLongPress,
  });

  final Trick trick;
  final TrickProgress? progress;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = progress ?? const TrickProgress();
    final trying = !p.learned && p.attempts > 0;
    // 배운 개인기는 별(배운 뒤 연습한 날 수), 배우는 중이면 점 세 개.
    final mark = p.learned
        ? '★' * p.stars
        : trying
        ? '…'
        : '';
    return Semantics(
      button: true,
      label: p.learned
          ? '${trick.label}, 별 ${p.stars}개'
          : trying
          ? '${trick.label}, 배우는 중'
          : trick.label,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        // 보이는 칩은 40, 누르는 자리는 위아래 4씩 더해 48.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.learned ? C3Colors.card : C3Colors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C3Colors.line, width: 1.2),
              boxShadow: const [
                BoxShadow(color: C3Colors.shadow, offset: Offset(0, 1.5)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trick.label, style: C3Text.label),
                if (mark.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    mark,
                    style: C3Text.label.copyWith(
                      color: p.learned ? C3Colors.stamp : C3Colors.hint,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
