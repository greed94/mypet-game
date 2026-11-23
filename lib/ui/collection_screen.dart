import 'package:flutter/material.dart';

import '../pet/guest.dart';
import '../pet/josa.dart';
import '../pet/pet_controller.dart';
import '../pet/treasure.dart';
import '../pet/treats.dart';
import '../services/telemetry.dart';
import 'c3/c3_theme.dart';
import 'c3/paper.dart';
import 'c3/pixel_icon.dart';
import 'c3/sticker_card.dart';
import 'c3/tape.dart';
import 'friends.dart';
import 'dress_up.dart';
import 'item_icon.dart';
import 'keep_words.dart';
import 'known_dog_screen.dart';
import 'memory_notebook.dart';

/// 도감. 날짜 없이 개수만 보여 준다. 못 찾은 칸은 모양만 흐리게.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.controller});

  final PetController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final found = items
            .where((i) => controller.finds.containsKey(i.id))
            .length;
        return PaperBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${controller.pet.name}의 도감',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: C3Text.title.copyWith(fontSize: 26),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MemoryNotebook(controller: controller),
                      ),
                    ),
                    icon: const PixelIcon('book'),
                    label: const Text('기억 수첩'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Tape(
                    color: C3Colors.tapeMint,
                    angle: -2,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Text('꾸미기', style: C3Text.label),
                    ),
                  ),
                  const Spacer(),
                  PawBalance(paws: controller.paws),
                ],
              ),
              const SizedBox(height: 10),
              DressUp(controller: controller),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Tape(
                  color: C3Colors.tapePink,
                  angle: -2,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text('아는 강아지', style: C3Text.label),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.74,
                children: [
                  for (final g in controller.knownDogs)
                    FriendTile(controller: controller, guest: g),
                  if (controller.knownDogs.length < maxKnownDogs)
                    _BringTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) =>
                              KnownDogScreen(controller: controller),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Tape(
                  color: C3Colors.tapeSky,
                  angle: -2,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text('카페 친구', style: C3Text.label),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.74,
                children: [
                  for (final g in cafeRegulars)
                    FriendTile(controller: controller, guest: g),
                ],
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                // 바로 아래 '늘 있는 것'이 노란 테이프라 붙어 보이지 않게.
                child: Tape(
                  color: C3Colors.tapeMint,
                  angle: -2,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Text('입맛', style: C3Text.label),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                keepWords('간식 가게에서 산 간식을 주면 반응이 적혀요.'),
                style: C3Text.body.copyWith(fontSize: 13, color: C3Colors.ink2),
              ),
              const SizedBox(height: 10),
              _Tastes(tried: controller.treatsTried),
              const SizedBox(height: 22),
              Text('동네에서 찾은 물건  $found / ${items.length}', style: C3Text.label),
              const SizedBox(height: 4),
              Text(
                keepWords('주워 온 물건을 누르면 방에 놓을 수 있어요.'),
                style: C3Text.body.copyWith(fontSize: 13, color: C3Colors.ink2),
              ),
              for (final pool in ItemPool.values) ...[
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tape(
                    color: _tape(pool),
                    angle: -2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Text(poolLabel(pool), style: C3Text.label),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 4,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                  children: [
                    for (final item in items.where((i) => i.pool == pool))
                      _Tile(controller: controller, item: item),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Color _tape(ItemPool pool) => switch (pool) {
    ItemPool.common => C3Colors.tapeYellow,
    ItemPool.autumn => C3Colors.tapePink,
    ItemPool.rain => C3Colors.tapeSky,
    ItemPool.night => C3Colors.tapeMint,
  };
}

/// 먹여 본 간식과 반응. 간식 가게에서 펫이 고른 걸 주면 하나씩 채워진다.
class _Tastes extends StatelessWidget {
  const _Tastes({required this.tried});

  final Map<String, Reaction> tried;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < treats.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _taste(treats[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < treats.length
                      ? _taste(treats[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _taste(Treat t) {
    final r = tried[t.id];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: C3Colors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r == Reaction.love ? C3Colors.stamp : C3Colors.line,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(t.color),
              shape: BoxShape.circle,
              border: Border.all(color: C3Colors.line),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: C3Text.label.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          // 싫어하는 간식은 냄새만 맡고 안 먹는다('이건… 별로야.'). 뱉는 게 아니라 '별로'.
          Text(
            switch (r) {
              Reaction.love => '좋아',
              Reaction.plain => '그냥',
              Reaction.meh => '별로',
              null => '?',
            },
            style: C3Text.label.copyWith(
              fontSize: 13,
              color: switch (r) {
                Reaction.love => C3Colors.ink,
                null => C3Colors.hint,
                _ => C3Colors.ink2,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 아는 강아지 데려오기 칸. 친구·가족네 강아지를 카페 손님으로 데려온다.
class _BringTile extends StatelessWidget {
  const _BringTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: C3Colors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: C3Colors.line, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Icon(Icons.add, size: 30, color: C3Colors.ink3),
                ),
              ),
              Text('데려오기', style: C3Text.label.copyWith(fontSize: 13)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '친구네 강아지',
                  maxLines: 1,
                  style: C3Text.body.copyWith(
                    fontSize: 12,
                    color: C3Colors.ink3,
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

class _Tile extends StatelessWidget {
  const _Tile({required this.controller, required this.item});

  final PetController controller;
  final Item item;

  String get _hint {
    if (item.rare) return '아주 가끔';
    return switch (item.pool) {
      ItemPool.common => '어디서든',
      ItemPool.autumn => '가을 산책',
      ItemPool.rain => '비 오는 날',
      ItemPool.night => '밤 창틀',
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = controller.finds[item.id];
    final found = f != null;
    return GestureDetector(
      onTap: found ? () => showPlaceDialog(context, controller, item) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: found ? C3Colors.card : C3Colors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: found ? null : Border.all(color: C3Colors.line, width: 1.2),
          boxShadow: found
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(98, 72, 50, .16),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ItemIcon(item, box: 44, silhouette: !found),
                    ),
                  ),
                  // 칸이 좁아 긴 이름(코스모스 꽃잎 등)은 잘리지 않게 글자를 줄인다.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      found ? item.name : '?',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: C3Text.label.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    found ? '×${f.count}' : _hint,
                    maxLines: 1,
                    style: C3Text.body.copyWith(
                      fontSize: 12,
                      color: C3Colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            if (f != null && f.giftCount > 0)
              const Positioned(
                top: 4,
                right: 4,
                child: PixelIcon('gift', scale: 1),
              ),
            if (controller.placedCount(item.id) > 0)
              const Positioned(
                top: 4,
                left: 4,
                child: PixelIcon('house', scale: 1),
              ),
          ],
        ),
      ),
    );
  }
}

/// 방 칸 고르기. 끌어다 놓기 없이 칸 이름을 누른다. 가진 개수보다 많이 놓으면 먼저 놓은 자리에서 옮겨 온다.
Future<void> showPlaceDialog(BuildContext context, PetController c, Item item) {
  Telemetry.track('place_open', {'item': item.id});
  return showC3Dialog<void>(
    context,
    title: item.name,
    body: ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final count = c.finds[item.id]?.count ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: ItemIcon(item, box: 88)),
            const SizedBox(height: 6),
            Text(
              '$count개 있어요 · 방에 ${c.placedCount(item.id)}개',
              textAlign: TextAlign.center,
              style: C3Text.body.copyWith(fontSize: 13, color: C3Colors.ink2),
            ),
            const SizedBox(height: 14),
            const Text('어디에 놓을까요?', style: C3Text.label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in slots)
                  _SlotChip(controller: c, slot: slot, item: item),
              ],
            ),
          ],
        );
      },
    ),
    actions: [
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('다 했어요'),
        ),
      ),
    ],
  );
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.controller,
    required this.slot,
    required this.item,
  });

  final PetController controller;
  final Slot slot;
  final Item item;

  Future<void> _tap() async {
    final c = controller;
    if (c.placed[slot.id] == item.id) {
      await c.place(slot.id, null);
      return;
    }
    final count = c.finds[item.id]?.count ?? 0;
    if (c.placedCount(item.id) >= count) {
      final from = c.placed.entries.firstWhere((e) => e.value == item.id).key;
      await c.place(from, null);
    }
    await c.place(slot.id, item.id);
  }

  @override
  Widget build(BuildContext context) {
    final here = controller.placed[slot.id];
    final mine = here == item.id;
    final other = here == null || mine ? null : itemById(here);
    return InkWell(
      onTap: _tap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDDF1E4) : C3Colors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: mine ? const Color(0xFF9FCBB4) : C3Colors.line,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot.label, style: C3Text.label.copyWith(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              mine ? '여기 있어요 · 치우기' : (other?.name ?? '비어 있음'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: C3Text.body.copyWith(fontSize: 12, color: C3Colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

/// 강아지가 떨어뜨린 걸 보여 준다. 방에 놓기를 고르면 칸 고르기로 이어진다.
Future<void> showFoundDialog(
  BuildContext context,
  PetController c,
  ReceiveResult r,
) async {
  final where = switch (r.source) {
    FindSource.gift => '잎사귀에 싸서 가져왔어요.',
    FindSource.comfort => '말없이 옆에 두고 갔어요.',
    FindSource.walk => '같이 산책하다가 주웠어요.',
    FindSource.window => '밤사이 창틀에 떨어져 있었어요.',
    FindSource.pocket => '주인이 걷는 동안 동네에서 주워 왔어요.',
    FindSource.friend => '카페 단짝이 아끼던 거예요. 두고 갔어요.',
    FindSource.hidden => '방석 밑에 몰래 숨겨 뒀던 거예요. 이제 보여 줘요.',
  };
  final title = r.source == FindSource.friend
      ? '단짝이 두고 간 것'
      : r.source == FindSource.hidden
      ? '숨겨 뒀던 보물'
      : r.gift
      ? '${josa(c.pet.name, '이/가')} 주는 선물'
      : (r.count == 1 ? '처음 보는 거다!' : '또 주워 왔어요');
  final place = await showC3Dialog<bool>(
    context,
    title: title,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ItemIcon(r.item, box: 96),
        const SizedBox(height: 8),
        Text(r.item.name, style: C3Text.label.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          keepWords(r.count > 1 ? '$where ${r.count}번째예요.' : where),
          textAlign: TextAlign.center,
          style: C3Text.body.copyWith(fontSize: 14, color: C3Colors.ink2),
        ),
      ],
    ),
    actions: [
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('도감에 넣기'),
        ),
      ),
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('방에 놓기'),
        ),
      ),
    ],
  );
  if (place == true && context.mounted) {
    await showPlaceDialog(context, c, r.item);
  }
}
