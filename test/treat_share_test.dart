import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treats.dart';

/// 발도장 쓰기(수익화 메모 '소모'): 간식 하나 더 사기, 카페 친구에게 간식 나눠 주기.
void main() {
  test('나눠 준 친구 기록은 그날만', () {
    final s = sharesTo('2026-10-05', {'coco', 'dubu'});
    expect(sharedOn(s, '2026-10-05'), {'coco', 'dubu'});
    expect(sharedOn(s, '2026-10-06'), isEmpty);
    expect(sharedOn(null, '2026-10-05'), isEmpty);
    expect(sharedOn('엉뚱한 값', '2026-10-05'), isEmpty);
  });

  test('손님은 걸어가 닿으면 시킨 동작을 마저 한다(간식 받으러 와서 먹기)', () {
    final mind = GuestMind(Random(1), seat: 0.8);
    mind.act(const [
      PetStep(Behavior.walk, 6, targetX: 0.4),
      PetStep(Behavior.eat, 2.5),
      PetStep(Behavior.happy, 1.5),
    ]);
    mind.arrived(night: false);
    expect(mind.step.behavior, Behavior.eat);
    mind.tick(2.6, night: false);
    expect(mind.step.behavior, Behavior.happy);
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = DateTime(2026, 10, 5, 15);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 5, 15);
    });
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> make({int paws = 0, String? pouch}) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 5)),
      );
      pet = pet.copyWith(
        lastSeenAt: now,
        paws: paws,
        treatPouch: Value(pouch),
        pawMarks: const Value('hidden'),
      );
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      return c;
    }

    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    void run(PetController c, bool Function() until) {
      for (var i = 0; i < 300 && !until(); i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
    }

    test('오늘 간식을 산 뒤 발도장 3으로 하나 더 산다(모자라거나 주머니가 차면 못 산다)', () async {
      final c = await make(paws: 5);
      c.goToTreatShop();
      run(c, () => c.pickShown);
      expect(c.canBuyExtraTreat, isFalse);
      expect(c.buyTreat(), isTrue);
      expect(c.canBuyExtraTreat, isTrue);
      expect(c.buyExtraTreat(), isTrue);
      expect(c.pet.paws, 5 - extraTreatPaws);
      expect(c.pouch, hasLength(2));
      // 남은 발도장 2로는 못 산다.
      expect(c.buyExtraTreat(), isFalse);
      expect(c.pouch, hasLength(2));
      await pumpEventQueue(times: 20);
      expect(await events('shop'), contains(contains('발도장으로')));
    });

    test('주머니가 차 있으면 발도장으로도 못 산다', () async {
      final c = await make(paws: 20, pouch: 'jerky,jerky');
      c.goToTreatShop();
      run(c, () => c.pickShown);
      c.buyTreat();
      expect(c.pouch, hasLength(pouchSize));
      expect(c.canBuyExtraTreat, isFalse);
    });

    Future<(PetController, Guest)> atCafe({
      Bond bond = Bond.sniff,
      String? pouch = 'cheese_ball,jerky',
    }) async {
      final c = await make(pouch: pouch);
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final g = c.guests.first;
      c.friends[g.id] = Friendship(bond: bond, days: 2, lastDay: 'x');
      return (c, g);
    }

    test('카페 친구에게 나눠 주면 그 애가 와서 먹고 일기에 남는다', () async {
      final (c, g) = await atCafe();
      expect(c.canShareWith(g.id), isTrue);
      final gen = c.shareGen;
      expect(c.shareTreat(g.id), isTrue);
      expect(c.shareGen, gen + 1);
      expect(c.shareGuest, g.id);
      expect(c.pouch, ['jerky']);
      expect(c.friends[g.id]!.bond, Bond.sniff);
      expect(c.step.thought, '같이 먹자!');
      // 같은 친구는 하루 한 번.
      expect(c.canShareWith(g.id), isFalse);
      expect(c.shareTreat(g.id), isFalse);
      await pumpEventQueue(times: 20);
      final line = (await events('share')).single;
      expect(line, startsWith('카페에서 '));
      expect(line, contains('치즈 볼을 나눠 줬'));
      expect((await db.loadPet())!.treatShares, '2026-10-05|${g.id}');
    });

    test('어제 낯섦이던 애도 오늘 만나 한 칸, 나눠 줘도 더 오르지 않는다(사이는 만난 날마다 한 칸)', () async {
      final c = await make(pouch: 'cheese_ball');
      for (final g in cafeRegulars) {
        c.friends[g.id] = const Friendship(
          bond: Bond.stranger,
          days: 1,
          lastDay: '2026-10-04',
        );
      }
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final g = c.guests.firstWhere((g) => cafeRegulars.contains(g));
      expect(c.friends[g.id]!.bond, Bond.sniff);
      expect(c.shareTreat(g.id), isTrue);
      expect(c.friends[g.id]!.bond, Bond.sniff);
    });

    test('처음 본 사이·주머니가 빔·밤엔 나눠 주지 않는다', () async {
      final (stranger, g) = await atCafe(bond: Bond.stranger);
      expect(stranger.canShareWith(g.id), isFalse);
      stranger.friends[g.id] = const Friendship(bond: Bond.sniff, days: 2);
      expect(stranger.canShareWith(g.id), isTrue);
      now = DateTime(2026, 10, 5, 22);
      expect(stranger.canShareWith(g.id), isFalse);
      now = DateTime(2026, 10, 5, 15);
      stranger.shareTreat(g.id);
      stranger.friends[g.id] = const Friendship(bond: Bond.sniff, days: 2);
      expect(stranger.canShareWith(g.id), isFalse);
    });

    test('주머니가 비면 나눠 줄 게 없다', () async {
      final (c, g) = await atCafe(pouch: null);
      expect(c.canShareWith(g.id), isFalse);
    });
  });
}
