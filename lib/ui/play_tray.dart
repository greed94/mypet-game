import 'package:flutter/material.dart';

import '../pet/tricks.dart';
import '../services/telemetry.dart';
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
    this.homePlay = false,
    this.compact = false,
    this.treats = 0,
    this.onTreat,
    this.onPointer,
  });

  final Map<Trick, TrickProgress> tricks;

  /// 훈련 수첩 열기. '수첩' 버튼과 칩 길게 누르기.
  final VoidCallback? onNotebook;

  /// 여기선 못 하는 개인기(카페의 '물어와').
  final Set<Trick> hide;
  final ValueChanged<Trick> onTrick;
  final VoidCallback onClose;
  final VoidCallback? onThrow;
  final bool homePlay;
  final bool compact;

  /// 주머니 간식 수. 개인기를 해낸 직후 주면 칭찬이 된다(놀이 칸이 밥·간식 줄을 가려서 여기에도 둔다).
  final int treats;
  final VoidCallback? onTreat;
  final void Function(PlayAction, Trick?, PointerEvent)? onPointer;

  Widget _input(PlayAction action, Widget child, {Trick? trick}) {
    final send = onPointer;
    if (send == null) return child;
    return Listener(
      onPointerDown: (e) => send(action, trick, e),
      onPointerCancel: (e) => send(action, trick, e),
      onPointerUp: (e) => send(action, trick, e),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeStyle = C3Text.label.copyWith(fontSize: 13);
    final badgeSize = _labelSize(context, badgeStyle, [
      '★★★',
      for (var n = 0; n < learnAfter; n++) '$n/$learnAfter',
    ]);
    final chips = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final t in Trick.values)
          if (t.chip && !hide.contains(t))
            _input(
              PlayAction.trick,
              _TrickChip(
                trick: t,
                progress: tricks[t],
                badgeSize: badgeSize,
                onTap: () => onTrick(t),
                onLongPress: onNotebook,
              ),
              trick: t,
            ),
      ],
    );
    final tools = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (homePlay || onThrow != null)
          _input(
            PlayAction.throwBall,
            TextButton(
              onPressed: onThrow,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: _ActionLabel(onThrow == null ? '공 준비 중' : '공 던지기', const [
                '공 준비 중',
                '공 던지기',
              ]),
            ),
          ),
        if (homePlay || treats > 0 && onTreat != null)
          _input(
            PlayAction.treat,
            TextButton(
              onPressed: treats > 0 ? onTreat : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: _ActionLabel('간식 $treats', const [
                '간식 0',
                '간식 1',
                '간식 2',
                '간식 3',
              ]),
            ),
          ),
        if (onNotebook != null)
          _input(
            PlayAction.notebook,
            TextButton(
              onPressed: onNotebook,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('훈련 수첩'),
            ),
          ),
      ],
    );
    final close = _input(
      PlayAction.close,
      TextButton(
        onPressed: onClose,
        style: TextButton.styleFrom(
          minimumSize: const Size(56, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('그만 놀기'),
      ),
    );
    final footer = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: compact
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 58),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [chips, tools],
                    ),
                  ),
                )
              : tools,
        ),
        const SizedBox(width: 8),
        close,
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 14, 16, 2),
      child: StickerCard(
        tape: C3Colors.tapeSky,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: compact
            ? footer
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [chips, footer],
              ),
      ),
    );
  }
}

// 표시가 바뀌어도 줄 높이와 너비가 바뀌지 않게 모든 후보의 한 줄 크기를 잰다.
Size _labelSize(BuildContext context, TextStyle style, List<String> labels) {
  final painter = TextPainter(
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  );
  final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  var width = 0.0;
  var height = 0.0;
  for (final label in labels) {
    painter.text = TextSpan(text: label, style: effectiveStyle);
    painter.layout();
    if (painter.width > width) width = painter.width;
    if (painter.height > height) height = painter.height;
  }
  painter.dispose();
  return Size(width.ceilToDouble(), height.ceilToDouble());
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label, this.labels);
  final String label;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: _labelSize(context, const TextStyle(), labels),
    child: Center(child: Text(label, maxLines: 1)),
  );
}

class _TrickChip extends StatelessWidget {
  const _TrickChip({
    required this.trick,
    required this.progress,
    required this.badgeSize,
    required this.onTap,
    this.onLongPress,
  });

  final Trick trick;
  final TrickProgress? progress;
  final Size badgeSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = progress ?? const TrickProgress();
    final trying = !p.learned && p.attempts > 0;
    // 첫 별까지 몇 번 더 해내야 하는지 칩에서도 볼 수 있다.
    final mark = p.learned
        ? '★' * p.stars
        : trying
        ? '${p.successes}/$learnAfter'
        : '';
    return Semantics(
      button: true,
      label: p.learned
          ? '${trick.label}, 별 ${p.stars}개'
          : trying
          ? '${trick.label}, 배우는 중, $learnAfter회 중 ${p.successes}회 성공'
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
                const SizedBox(width: 4),
                SizedBox.fromSize(
                  size: badgeSize,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      mark,
                      maxLines: 1,
                      style: C3Text.label.copyWith(
                        color: p.learned ? C3Colors.stamp : C3Colors.hint,
                        fontSize: 13,
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
}
