import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 9, 26, 14);
  int? stepTotal;
  var reads = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 26, 14);
    stepTotal = null;
    reads = 0;
  });
  // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<int?> read() async {
    reads++;
    return stepTotal;
  }

  PetController controllerFor(Pet pet, int seed) => PetController(
    db,
    pet,
    readStepTotal: read,
    random: Random(seed),
    clock: () => now,
  );

  Future<PetController> make() async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(lastSeenAt: now);
    await db.savePet(pet);
    final c = controllerFor(pet, 1);
    c.wake();
    await c.collected;
    while (c.carried.isNotEmpty) {
      await c.receive();
    }
    return c;
  }

  Future<PetController> reopen(PetController old, Duration later) async {
    old.sleepApp();
    await pumpEventQueue();
    now = now.add(later);
    final c = controllerFor((await db.loadPet())!, 2);
    c.wake();
    await c.collected;
    return c;
  }

  int pocket(PetController c) =>
      c.carried.where((i) => i.source == FindSource.pocket).length;

  test('자주 열어도 1500걸음이 안 된 나머지는 쌓여서 결국 줍는다', () async {
    stepTotal = 5000;
    var c = await make();
    stepTotal = 6200;
    c = await reopen(c, const Duration(minutes: 20));
    expect(pocket(c), 0);
    stepTotal = 7400;
    c = await reopen(c, const Duration(minutes: 20));
    expect(pocket(c), 1);
    stepTotal = 8600;
    c = await reopen(c, const Duration(minutes: 20));
    expect(pocket(c), 2);
  });

  test('앱 안에서 산책한 걸음은 다음에 열 때 주머니 걸음으로 다시 세지 않는다', () async {
    stepTotal = 5000;
    final c = await make();
    c.startWalk();
    c.updateWalkSteps(3000);
    now = now.add(const Duration(minutes: 25));
    c.endWalk();
    await pumpEventQueue();
    stepTotal = 8000;
    final again = await reopen(c, const Duration(minutes: 5));
    expect(pocket(again), 0);
  });

  test('산책 중에 앱으로 돌아오면 누적 걸음을 읽지 않는다', () async {
    stepTotal = 5000;
    final c = await make();
    final before = reads;
    c.startWalk();
    await c.collectNow();
    expect(reads, before);
  });

  group('위로 선물', () {
    test('좋아하는 계열로 오고, 받으면 말풍선 없이 옆에 엎드린다', () async {
      final c = await make();
      await c.talk('오늘 너무 지쳤어');
      final again = await reopen(c, const Duration(hours: 1));
      final comfort = again.carried.where(
        (i) => i.source == FindSource.comfort,
      );
      expect(comfort, hasLength(1));
      expect(itemById(comfort.single.itemId)!.taste, again.pet.likeTaste);
      final r = (await again.receive())!;
      expect(r.gift, isTrue);
      expect(again.step.behavior, Behavior.lieBeside);
      expect(again.bubble, isNull);
    });

    test('지친 말 뒤에 위기 표현이 오면 예약된 선물을 지운다', () async {
      final c = await make();
      await c.talk('힘들어');
      expect(c.pet.comfortDue, isTrue);
      expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
      expect(c.pet.comfortDue, isFalse);
      final again = await reopen(c, const Duration(hours: 1));
      expect(
        again.carried.where((i) => i.source == FindSource.comfort),
        isEmpty,
      );
    });

    test('위기 표현 뒤 하루 동안은 지친 말에도 선물을 잡지 않는다', () async {
      final c = await make();
      await c.talk('죽고 싶어');
      await c.talk('진짜 힘들어');
      expect(c.pet.comfortDue, isFalse);
      now = now.add(const Duration(hours: 25));
      await c.talk('오늘도 힘들었어');
      expect(c.pet.comfortDue, isTrue);
    });

    test('하루 한 번만 온다', () async {
      var c = await make();
      await c.talk('힘들어');
      c = await reopen(c, const Duration(minutes: 30));
      expect(
        c.carried.where((i) => i.source == FindSource.comfort),
        hasLength(1),
      );
      while (c.carried.isNotEmpty) {
        await c.receive();
      }
      await c.talk('또 힘들어');
      c = await reopen(c, const Duration(minutes: 30));
      expect(c.carried.where((i) => i.source == FindSource.comfort), isEmpty);
    });
  });
}
