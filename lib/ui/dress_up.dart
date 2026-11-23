import 'package:flutter/material.dart';

import '../pet/paws.dart';
import '../pet/pet_controller.dart';
import 'c3/c3_theme.dart';
import 'c3/pixel_icon.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';

/// 가진 발도장 수. 도감 머리와 꾸미기 칸 위에 쓴다.
class PawBalance extends StatelessWidget {
  const PawBalance({super.key, required this.paws});

  final int paws;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '발도장 $paws개',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 10, 4),
        decoration: BoxDecoration(
          color: C3Colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C3Colors.line, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PixelIcon('paw_ink', scale: 2),
            const SizedBox(width: 4),
            Text('$paws', style: C3Text.label),
          ],
        ),
      ),
    );
  }
}

/// 도감의 꾸미기 칸. 목걸이 색과 방석 색. 가진 건 누르면 쓰고, 아니면 발도장으로 바꾼다.
class DressUp extends StatelessWidget {
  const DressUp({super.key, required this.controller});

  final PetController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          keepWords('발도장은 산책·소원·발표회·검진·저녁 이야기로 모여요.'),
          style: C3Text.body.copyWith(fontSize: 13, color: C3Colors.ink2),
        ),
        const SizedBox(height: 10),
        for (final kind in CosmeticKind.values) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in cosmetics)
                if (item.kind == kind)
                  _CosmeticTile(
                    item: item,
                    owned: c.ownedCosmetics.contains(item.id),
                    worn:
                        (kind == CosmeticKind.collar ? c.collar : c.rug).id ==
                        item.id,
                    onTap: () => _pick(context, item),
                  ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context, Cosmetic item) async {
    final c = controller;
    if (c.ownedCosmetics.contains(item.id)) {
      c.wearCosmetic(item.id);
      return;
    }
    if (c.paws < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('발도장이 ${item.price - c.paws}개 더 있으면 돼요.')),
      );
      return;
    }
    final yes = await showC3Dialog<bool>(
      context,
      title: item.label,
      body: Text(keepWords('발도장 ${item.price}개로 바꿔서 바로 쓸까요?')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('그만두기'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('바꾸기'),
        ),
      ],
    );
    if (yes == true) c.buyCosmetic(item.id);
  }
}

class _CosmeticTile extends StatelessWidget {
  const _CosmeticTile({
    required this.item,
    required this.owned,
    required this.worn,
    required this.onTap,
  });

  final Cosmetic item;
  final bool owned;
  final bool worn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = worn
        ? '쓰는 중'
        : owned
        ? '가짐'
        : '발도장 ${item.price}';
    return Semantics(
      button: true,
      selected: worn,
      label: '${item.label}, $note',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        child: Container(
          width: 76,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          decoration: BoxDecoration(
            color: C3Colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: worn ? C3Colors.stamp : C3Colors.line,
              width: worn ? 2.2 : 1.2,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Center(child: _Swatch(item: item)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: C3Text.label.copyWith(fontSize: 12),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  note,
                  maxLines: 1,
                  style: C3Text.body.copyWith(
                    fontSize: 12,
                    color: worn ? C3Colors.stamp : C3Colors.ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 목걸이는 색 동그라미, 방석은 세 겹 타원(방에 깔린 것과 같은 색).
class _Swatch extends StatelessWidget {
  const _Swatch({required this.item});

  final Cosmetic item;

  @override
  Widget build(BuildContext context) {
    if (item.kind == CosmeticKind.collar) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Color(item.colors.first),
          shape: BoxShape.circle,
          border: Border.all(color: C3Colors.line, width: 1.5),
        ),
      );
    }
    return SizedBox(
      width: 52,
      height: 22,
      child: CustomPaint(painter: _RugPainter(item.colors)),
    );
  }
}

class _RugPainter extends CustomPainter {
  _RugPainter(this.colors);

  final List<int> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = Paint();
    canvas.drawOval(r, p..color = Color(colors[0]));
    canvas.drawOval(r.deflate(3), p..color = Color(colors[1]));
    canvas.drawOval(r.deflate(7), p..color = Color(colors[2]));
  }

  @override
  bool shouldRepaint(_RugPainter old) => old.colors != colors;
}
