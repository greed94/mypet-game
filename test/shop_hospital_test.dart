import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/checkup.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/treats.dart';

void main() {
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

  Future<PetController> make({
    PetStage stage = PetStage.adult,
    Taste like = Taste.round,
    Taste dislike = Taste.smelly,
  }) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: stage,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    pet = pet.copyWith(
      lastSeenAt: now,
      likeTaste: Value(like),
      dislikeTaste: Value(dislike),
    );
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    return c;
  }

  /// 게임이 하던 일: 걷는 중이면 도착시키고, 아니면 1초씩 흘린다.
  void run(PetController c, {required bool Function() until, int max = 300}) {
    for (var i = 0; i < max && !until(); i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
  }

  Future<List<String>> events(String kind) async => [
    for (final e in await db.eventsOn(now))
      if (e.kind == kind) e.detail,
  ];

  group('간식 가게', () {
    test('진열장을 다 킁킁 돈 뒤 좋아하는 갈래 앞에 앉고, 그때부터 살 수 있다', () async {
      final c = await make(like: Taste.round);
      expect(c.goToTreatShop(), isTrue);
      expect(c.spot, Spot.treatShop);
      expect(c.lineup.length, shopSlots.length);
      expect(c.buyTreat(), isFalse);

      var sniffs = 0;
      run(
        c,
        until: () {
          if (c.step.behavior == Behavior.sniff) sniffs++;
          return c.pickShown;
        },
      );
      expect(c.pickShown, isTrue);
      expect(sniffs, greaterThanOrEqualTo(shopSlots.length));
      final pick = c.shopPick!;
      if (c.lineup.any((t) => t.taste == Taste.round)) {
        expect(pick.taste, Taste.round);
      }
      expect(c.bubble, '이거!');

      expect(c.buyTreat(), isTrue);
      expect(c.pouch, [pick.id]);
      expect(c.boughtToday, isTrue);
      expect(c.buyTreat(), isFalse);
      expect((await db.loadPet())!.treatPouch, pick.id);
      expect(await events('shop'), [contains('사 줬다')]);

      c.comeHome();
      await pumpEventQueue();
      expect(await events('shop'), hasLength(1));
    });

    test('진열장을 도는 중에 쓰다듬어도 결국 고른 칸 앞에 앉아 살 수 있다', () async {
      final c = await make();
      c.goToTreatShop();
      run(c, until: () => c.step.behavior == Behavior.sniff);
      c.interact(Interaction.pet);
      double? lastWalk;
      run(
        c,
        until: () {
          if (c.step.behavior == Behavior.walk) lastWalk = c.step.targetX;
          return c.pickShown;
        },
      );
      expect(c.pickShown, isTrue);
      expect(c.step.tag, StepTag.pick);
      expect(lastWalk, shopSlots[c.shopPickIndex!]);
      expect(c.buyTreat(), isTrue);
    });

    test('같은 날 둘러보기만 한 방문과 산 방문이 둘 다 맞게 남는다', () async {
      final c = await make();
      c.goToTreatShop();
      c.comeHome();
      c.goToTreatShop();
      run(c, until: () => c.pickShown);
      c.buyTreat();
      c.comeHome();
      c.goToTreatShop();
      c.comeHome();
      await pumpEventQueue(times: 20);
      expect(await events('shop_visit'), [contains('냄새만')]);
      expect(await events('shop'), [contains('사 줬다')]);
    });

    test('사지 않고 나오면 냄새만 맡았다고 남고, 같은 날 또 와도 한 번이다', () async {
      final c = await make();
      c.goToTreatShop();
      c.comeHome();
      c.goToTreatShop();
      c.comeHome();
      await pumpEventQueue(times: 20);
      expect(await events('shop_visit'), [contains('냄새만')]);
      expect(await events('shop'), isEmpty);
    });

    test('하루 하나씩, 주머니는 셋까지', () async {
      final c = await make();
      for (var day = 0; day < 4; day++) {
        c.goToTreatShop();
        run(c, until: () => c.pickShown);
        c.buyTreat();
        c.comeHome();
        now = now.add(const Duration(days: 1));
      }
      expect(c.pouch.length, pouchSize);
      c.goToTreatShop();
      run(c, until: () => c.pickShown);
      expect(c.buyTreat(), isFalse);
    });

    test('집에서 간식을 주면 먼저 산 것부터 먹고, 좋아하는 갈래면 크게 기뻐한다', () async {
      final c = await make(like: Taste.round, dislike: Taste.smelly);
      final pet = (await db.loadPet())!.copyWith(
        treatPouch: const Value('cheese_ball,jerky'),
      );
      await db.savePet(pet);
      final home = PetController(db, pet, random: Random(3), clock: () => now);
      home.wake();
      await home.collected;
      home.step = const PetStep(Behavior.idle, 3);
      final mood = home.stats.mood;

      home.giveTreat();
      expect(home.pouch, ['jerky']);
      expect(home.stats.mood, greaterThan(mood));
      expect(home.step.behavior, Behavior.eat);
      expect(home.bubble, isNull);
      run(home, until: () => home.step.behavior == Behavior.happy, max: 10);
      expect(home.bubble, '치즈 볼 최고야!');

      home.step = const PetStep(Behavior.idle, 3);
      home.giveTreat();
      expect(home.pouch, isEmpty);
      expect(home.step.behavior, Behavior.sniff);
      expect(home.bubble, '이건… 별로야.');
      await pumpEventQueue();
      expect(await events('treat'), hasLength(2));
      expect(c.out, isFalse);
    });

    test('깊이 자면 간식을 꺼내도 먹지 않고 그대로 둔다. 집 밖에선 꺼낼 수 없다', () async {
      final c = await make();
      final pet = (await db.loadPet())!.copyWith(
        treatPouch: const Value('cheese_ball'),
      );
      await db.savePet(pet);
      final home = PetController(db, pet, random: Random(3), clock: () => now);
      home.wake();
      await home.collected;
      home.step = const PetStep(Behavior.sleep, 30);
      home.stats = home.stats.copyWith(energy: tiredEnergy - 1);
      home.giveTreat();
      expect(home.pouch, ['cheese_ball']);
      expect(home.bubble, '…쿨.');

      home.stats = home.stats.copyWith(energy: 80);
      home.step = const PetStep(Behavior.idle, 3);
      home.goToTreatShop();
      home.giveTreat();
      expect(home.pouch, ['cheese_ball']);
      expect(c.pouch, isEmpty);
    });
  });

  group('병원', () {
    test('검진한 날엔 다시 들어가도 수첩을 다시 볼 수 있다', () async {
      final c = await make();
      c.goToHospital();
      final record = c.startCheckup()!;
      c.comeHome();
      c.goToHospital();
      expect(c.lastCheckup?.weight, record.weight);
      expect(c.startCheckup(), isNull);
    });

    test('검진은 체중계에 올라가 몸무게를 재고, 일주일에 한 번이다', () async {
      final c = await make(stage: PetStage.puppy);
      expect(c.goToHospital(), isTrue);
      expect(c.spot, Spot.hospital);
      expect(c.daysToCheckup, 0);

      final first = c.startCheckup()!;
      expect(first.shotLabel, '1/3차');
      expect(c.lastCheckup, same(first));
      expect(c.step.targetX, scaleX);
      run(c, until: () => c.step.tag == StepTag.weigh, max: 5);
      expect(c.step.tag, StepTag.weigh);
      run(c, until: () => c.step.behavior == Behavior.happy, max: 10);
      expect(c.bubble, '잘 참았다!');

      final saved = (await db.loadPet())!;
      expect(saved.checkups, 1);
      expect(saved.lastWeight, first.weight);
      expect(await events('hospital'), [contains('${first.weight}kg')]);

      expect(c.startCheckup(), isNull);
      c.comeHome();
      now = now.add(const Duration(days: 1));
      expect(c.daysToCheckup, 6);

      now = now.add(const Duration(days: 6));
      c.goToHospital();
      expect(c.lastCheckup, isNull);
      final second = c.startCheckup()!;
      expect(second.shotLabel, '2/3차');
      expect(second.previousWeight, first.weight);
      expect(second.change, isNotNull);
    });

    test(
      '검진 없이 나오면 무서워서 금방 나왔다고 하루 한 번 남고, 검진받은 날 다시 와서 나가도 검진 기록은 그대로다',
      () async {
        final c = await make();
        c.goToHospital();
        c.comeHome();
        c.goToHospital();
        c.comeHome();
        await pumpEventQueue(times: 20);
        expect(await events('hospital_visit'), [contains('금방 나왔다')]);
        expect(await events('hospital'), isEmpty);

        c.goToHospital();
        c.startCheckup();
        c.comeHome();
        c.goToHospital();
        expect(c.lastCheckup, isNotNull);
        c.comeHome();
        await pumpEventQueue(times: 20);
        expect(await events('hospital'), [contains('잘 참았다')]);
        expect(await events('hospital_visit'), hasLength(1));
      },
    );

    test('병원에선 입구 쪽에서 머뭇거린다', () async {
      final c = await make();
      c.goToHospital();
      final seen = <Behavior>{};
      for (var i = 0; i < 200; i++) {
        if (c.step.behavior == Behavior.walk) {
          final t = c.step.targetX;
          if (t != null && i > 5) expect(t, inInclusiveRange(0.15, 0.4));
          c.arrived();
        } else {
          c.tick(1);
        }
        seen.add(c.step.behavior);
      }
      expect(seen, containsAll([Behavior.sit, Behavior.sniff]));
      expect(seen, isNot(contains(Behavior.sleep)));
    });
  });
}
