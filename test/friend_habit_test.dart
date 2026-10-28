import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/quirks.dart';

/// 친구한테 배운 버릇(아이디어 #14): 카페에서 사흘 내리 어울린 친구의 버릇이 옮고,
/// 그 친구를 일주일 넘게 못 보면 슬그머니 사라진다.
void main() {
  group('규칙', () {
    test('만난 날이 이어지면 내리 만난 날이 늘고, 하루라도 건너뛰면 처음부터, 같은 날은 그대로', () {
      var f = const Friendship();
      f = f.met('2026-10-05');
      expect(f.streak, 1);
      f = f.met('2026-10-06').met('2026-10-07');
      expect(f.streak, 3);
      expect(identical(f.met('2026-10-07'), f), isTrue);
      f = f.met('2026-10-09');
      expect(f.streak, 1);
      expect(f.named('토토').streak, 1);
      // 달이 바뀌어도 이어진다.
      expect(
        const Friendship(
          lastDay: '2026-10-31',
          streak: 2,
        ).met('2026-11-01').streak,
        3,
      );
    });

    test('손님 버릇은 손님마다 정해져 있고, 일기 줄은 조사까지 맞다', () {
      expect(guestQuirk('coco'), guestQuirk('coco'));
      expect(
        habitCaughtLine('코코', Quirk.sitBeforeEat),
        '코코와 사흘 내리 놀았더니 밥 앞에서 앉는 버릇이 옮았다',
      );
      expect(
        habitFadedLine('두부', Quirk.hopWhenPetted),
        '요즘 두부를 못 봐서 쓰다듬으면 폴짝 뛰는 버릇이 슬그머니 없어졌다',
      );
      expect(habitFadedLine(null, Quirk.hopWhenPetted), startsWith('친구한테 옮은'));
    });
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = DateTime(2026, 10, 6, 14);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 6, 14);
    });
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> make(Quirk quirk, {String? habit}) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
      );
      pet = pet.copyWith(
        lastSeenAt: now,
        affection: 50,
        quirk: Value(quirk.name),
        habit: Value(habit),
        pawMarks: const Value('hidden'),
      );
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
      c.step = const PetStep(Behavior.idle, 3);
      return c;
    }

    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    test('카페에서 사흘 내리 같은 친구와 어울리면 그 친구 버릇이 옮는다', () async {
      // 같은 단골이 사흘 내리 오는 날을 손님 배정에서 찾는다.
      late DateTime start;
      var common = <String>{};
      for (var d = 0; d < 90 && common.isEmpty; d++) {
        start = DateTime(2026, 10, 6, 14).add(Duration(days: d));
        common = guestsAt(start).map((g) => g.id).toSet();
        for (var i = 1; i < catchStreak; i++) {
          common = common.intersection(
            guestsAt(start.add(Duration(days: i))).map((g) => g.id).toSet(),
          );
        }
      }
      expect(common, isNotEmpty);
      final theirs = {for (final id in common) guestQuirk(id)};
      final own = Quirk.values.firstWhere(
        (q) => !theirs.contains(q),
        orElse: () => Quirk.values.first,
      );
      now = start;
      final c = await make(own);
      for (var i = 0; i < catchStreak; i++) {
        expect(c.goToCafe(), isTrue);
        await pumpEventQueue(times: 50);
        if (i < catchStreak - 1) {
          expect(c.learnedQuirk, isNull);
          c.comeHome();
          now = now.add(const Duration(days: 1));
        }
      }
      expect(theirs.where((q) => q != own), contains(c.learnedQuirk));
      await pumpEventQueue(times: 20);
      expect(await events('friend_habit'), hasLength(1));
      expect((await events('friend_habit')).single, contains('사흘 내리 놀았더니'));
      expect(
        (await db.loadPet())!.habit,
        startsWith('${c.learnedQuirk!.name}|'),
      );
      // 내리 만난 날은 앱을 다시 켜도 이어지게 저장된다.
      expect(
        (await db.loadFriends()).values.map((f) => f.streak),
        contains(catchStreak),
      );
    });

    test('이미 단짝인 친구도 하루 만난 걸로는 안 옮는다(사흘 내리여야)', () async {
      final g = guestsAt(now).first;
      await db.saveFriend(
        g.id,
        const Friendship(
          bond: Bond.bestie,
          days: 10,
          lastDay: '2026-09-01',
          streak: 1,
        ),
      );
      final own = Quirk.values.firstWhere((q) => q != guestQuirk(g.id));
      final c = await make(own);
      expect(c.goToCafe(), isTrue);
      await pumpEventQueue(times: 50);
      expect(c.friends[g.id]?.streak, 1);
      expect(c.learnedQuirk, isNull);
    });

    test('친구 버릇이 우리 애 버릇과 같으면 옮을 게 없다', () async {
      // 단골 하나만 사흘 내리 오는 날을 찾는다.
      late DateTime start;
      var common = <String>{};
      for (var d = 0; d < 200 && common.length != 1; d++) {
        start = DateTime(2026, 10, 6, 14).add(Duration(days: d));
        common = guestsAt(start).map((g) => g.id).toSet();
        for (var i = 1; i < catchStreak; i++) {
          common = common.intersection(
            guestsAt(start.add(Duration(days: i))).map((g) => g.id).toSet(),
          );
        }
      }
      expect(common, hasLength(1));
      now = start;
      final c = await make(guestQuirk(common.single));
      for (var i = 0; i < catchStreak; i++) {
        expect(c.goToCafe(), isTrue);
        await pumpEventQueue(times: 50);
        c.comeHome();
        now = now.add(const Duration(days: 1));
      }
      expect(c.learnedQuirk, isNull);
    });

    test('옮은 버릇과 원래 버릇을 둘 다 한다(밥 앞에서 앉고, 다 먹고 빈 그릇 킁킁)', () async {
      await db.saveFriend(
        'bori',
        const Friendship(
          bond: Bond.play,
          days: 3,
          lastDay: '2026-10-05',
          streak: 3,
        ),
      );
      final c = await make(Quirk.sniffBowlAfter, habit: 'sitBeforeEat|bori');
      await pumpEventQueue(times: 20);
      expect(c.learnedQuirk, Quirk.sitBeforeEat);
      c.stats = c.stats.copyWith(hunger: 80);
      c.interact(Interaction.feed);
      final seen = <(Behavior, StepTag)>[];
      PetStep? last;
      for (var i = 0; i < 8; i++) {
        if (!identical(c.step, last)) {
          last = c.step;
          seen.add((c.step.behavior, c.step.tag));
        }
        c.tick(1);
      }
      expect(seen.take(3), [
        (Behavior.sit, StepTag.bowl),
        (Behavior.eat, StepTag.none),
        (Behavior.sniff, StepTag.bowl),
      ]);
    });

    test('그 친구를 일주일 넘게 못 보면 열 때 슬그머니 사라지고 일기에 남는다', () async {
      await db.saveFriend(
        'coco',
        const Friendship(
          bond: Bond.play,
          days: 3,
          lastDay: '2026-09-28',
          streak: 3,
        ),
      );
      final c = await make(
        Quirk.sniffBowlAfter,
        habit: 'circleBeforeSleep|coco',
      );
      await pumpEventQueue(times: 20);
      expect(c.learnedQuirk, isNull);
      expect((await db.loadPet())!.habit, isNull);
      final coco = cafeRegulars.firstWhere((g) => g.id == 'coco');
      expect(await events('friend_habit_gone'), [
        habitFadedLine(coco.look, Quirk.circleBeforeSleep),
      ]);
    });

    test('일주일이 안 지났으면 그대로 둔다', () async {
      await db.saveFriend(
        'coco',
        const Friendship(
          bond: Bond.play,
          days: 3,
          lastDay: '2026-09-29',
          streak: 3,
        ),
      );
      // 마지막으로 본 지 딱 이레(펫의 날)면 아직 '일주일 넘게'가 아니다.
      final c = await make(
        Quirk.sniffBowlAfter,
        habit: 'circleBeforeSleep|coco',
      );
      await pumpEventQueue(times: 20);
      expect(c.learnedQuirk, Quirk.circleBeforeSleep);
      expect(await events('friend_habit_gone'), isEmpty);
    });

    test('버릇이 사라지는 그 열기엔 그 버릇을 하지 않는다(반긴 뒤 발 냄새)', () async {
      await db.saveFriend(
        'choco',
        const Friendship(bond: Bond.play, days: 3, lastDay: '2026-10-05'),
      );
      final c = await make(
        Quirk.sniffBowlAfter,
        habit: 'sniffOwnerAfterGreet|choco',
      );
      await pumpEventQueue(times: 20);
      expect(c.learnedQuirk, Quirk.sniffOwnerAfterGreet);
      c.sleepApp();
      now = DateTime(2026, 10, 15, 14);
      c.wake();
      expect(c.learnedQuirk, isNull);
      final steps = <PetStep>[];
      PetStep? last;
      for (var i = 0; i < 25; i++) {
        if (!identical(c.step, last)) {
          last = c.step;
          steps.add(c.step);
        }
        now = now.add(const Duration(seconds: 1));
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
      expect(
        steps.any((s) => s.behavior == Behavior.sniff && s.thought == null),
        isFalse,
      );
    });

    test('옮긴 친구를 오래 못 봐도 같은 버릇을 가진 다른 친구를 만나고 있으면 이어진다', () async {
      await db.saveFriend(
        'coco',
        const Friendship(bond: Bond.play, days: 3, lastDay: '2026-09-20'),
      );
      await db.saveFriend(
        'dubu',
        const Friendship(bond: Bond.play, days: 5, lastDay: '2026-10-04'),
      );
      final c = await make(
        Quirk.sniffBowlAfter,
        habit: 'circleBeforeSleep|coco',
      );
      await pumpEventQueue(times: 20);
      expect(c.learnedQuirk, Quirk.circleBeforeSleep);
    });

    test('같은 날 두 친구가 사흘째여도 버릇은 하나만, 일기도 한 줄', () async {
      final here = guestsAt(now);
      final two = [
        for (final g in here)
          if (here.where((x) => guestQuirk(x.id) == guestQuirk(g.id)).length ==
              1)
            g,
      ];
      expect(two.length, greaterThanOrEqualTo(2));
      for (final g in two) {
        await db.saveFriend(
          g.id,
          const Friendship(
            bond: Bond.sniff,
            days: 2,
            lastDay: '2026-10-05',
            streak: 2,
          ),
        );
      }
      final own = Quirk.values.firstWhere(
        (q) => two.every((g) => guestQuirk(g.id) != q),
      );
      final c = await make(own);
      expect(c.goToCafe(), isTrue);
      await pumpEventQueue(times: 50);
      expect(c.learnedQuirk, isNotNull);
      expect(await events('friend_habit'), hasLength(1));
    });

    test('이미 사흘을 넘긴 다른 친구가 와도 버릇이 날마다 뒤집히지 않는다(문턱을 넘는 날만 옮는다)', () async {
      final b = guestsAt(now).first;
      final a = cafeRegulars.firstWhere(
        (g) => guestQuirk(g.id) != guestQuirk(b.id),
      );
      await db.saveFriend(
        b.id,
        const Friendship(
          bond: Bond.bestie,
          days: 6,
          lastDay: '2026-10-05',
          streak: 3,
        ),
      );
      await db.saveFriend(
        a.id,
        const Friendship(
          bond: Bond.play,
          days: 3,
          lastDay: '2026-10-05',
          streak: 3,
        ),
      );
      final own = Quirk.values.firstWhere(
        (q) => q != guestQuirk(a.id) && q != guestQuirk(b.id),
      );
      final c = await make(own, habit: '${guestQuirk(a.id).name}|${a.id}');
      expect(c.goToCafe(), isTrue);
      await pumpEventQueue(times: 50);
      expect(c.learnedQuirk, guestQuirk(a.id));
      expect(await events('friend_habit'), isEmpty);
    });

    test('쓰다듬으면 폴짝인 애가 밥 앞에서 앉는 버릇이 옮았어도, 앉은 사이 쓰다듬으면 밥은 먹는다', () async {
      await db.saveFriend(
        'bori',
        const Friendship(bond: Bond.play, days: 3, lastDay: '2026-10-05'),
      );
      final c = await make(Quirk.hopWhenPetted, habit: 'sitBeforeEat|bori');
      await pumpEventQueue(times: 20);
      c.stats = c.stats.copyWith(hunger: 80);
      c.interact(Interaction.feed);
      expect(c.step.tag, StepTag.bowl);
      c.interact(Interaction.pet);
      var ate = false;
      for (var i = 0; i < 6 && !ate; i++) {
        c.tick(1);
        ate = c.step.behavior == Behavior.eat;
      }
      expect(ate, isTrue);
    });
  });
}
