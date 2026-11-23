import 'dart:async';
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
  Completer<int?>? slowRead;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 26, 14);
    stepTotal = null;
    reads = 0;
    slowRead = null;
  });
  // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<int?> read() async {
    reads++;
    if (slowRead case final pending?) return pending.future;
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

  test('첫 권한을 산책에서 허락해도 귀가 뒤 1500걸음과 첫 주머니 선물을 각각 한 번 받는다', () async {
    stepTotal = null;
    final c = await make();
    expect(c.pet.pocketDay, isNull);
    expect(c.startWalk(), isTrue);
    c.updateWalkSteps(0, deviceTotal: 10000);
    c.updateWalkSteps(100, deviceTotal: 10100);
    now = now.add(const Duration(minutes: 3));
    c.endWalk();
    await c.settled;
    final fromWalk = (await db.loadPet())!;
    expect(fromWalk.lastStepTotal, 10100);
    expect(fromWalk.pocketWelcomePending, isTrue);
    stepTotal = 11600;
    final again = await reopen(c, const Duration(minutes: 20));
    expect(pocket(again), 1);
    expect(again.pet.pocketWelcomePending, isFalse);
    expect(again.carried.where((i) => i.gift), hasLength(1));
    final later = await reopen(again, const Duration(minutes: 1));
    expect(pocket(later), 1);
    expect(later.carried.where((i) => i.gift), hasLength(1));
  });

  test('기기 누적값 초기화 전후의 산책 걸음은 다음 주머니 보상으로 다시 세지 않는다', () async {
    stepTotal = 10000;
    final c = await make();
    c.startWalk();
    c.updateWalkSteps(0, deviceTotal: 10000);
    c.updateWalkSteps(100, deviceTotal: 10100);
    c.markWalkSensorUnavailable();
    c.updateWalkSteps(100, deviceTotal: 0);
    c.updateWalkSteps(1900, deviceTotal: 1800);
    now = now.add(const Duration(minutes: 20));
    expect(c.endWalk().steps, 1900);
    await c.settled;
    expect(c.pet.lastStepTotal, 1800);
    stepTotal = 1800;
    final again = await reopen(c, const Duration(minutes: 1));
    expect(pocket(again), 0);
    stepTotal = 3300;
    final later = await reopen(again, const Duration(minutes: 15));
    expect(pocket(later), 1);
  });

  test('산책 전 1400걸음은 센서 초기화와 재실행 뒤에도 남아 밖에서 100걸음 더 걸으면 줍는다', () async {
    stepTotal = 10000;
    final c = await make();
    expect(c.startWalk(), isTrue);
    c.updateWalkSteps(0, deviceTotal: 11400);
    c.updateWalkSteps(100, deviceTotal: 11500);
    c.markWalkSensorUnavailable();
    c.updateWalkSteps(100, deviceTotal: 0);
    c.updateWalkSteps(200, deviceTotal: 100);
    now = now.add(const Duration(minutes: 4));
    c.endWalk();
    await c.settled;
    final saved = (await db.loadPet())!;
    expect(saved.pocketStepCredit, 1400);
    expect(saved.lastStepTotal, 100);
    stepTotal = 200;
    final again = await reopen(c, const Duration(minutes: 2));
    expect(pocket(again), 1);
    expect(again.pet.pocketStepCredit, 0);
    final later = await reopen(again, const Duration(minutes: 1));
    expect(pocket(later), 1);
  });

  test('주머니 계수를 읽는 사이 끝난 산책의 걸음은 오래된 응답으로 되돌리지 않는다', () async {
    stepTotal = 5000;
    final c = await make();
    final before = reads;
    slowRead = Completer<int?>();
    final pending = c.collectNow();
    for (var i = 0; i < 100 && reads == before; i++) {
      await pumpEventQueue();
    }
    expect(reads, before + 1);
    c.startWalk();
    c.updateWalkSteps(1500, deviceTotal: 6500);
    now = now.add(const Duration(minutes: 5));
    c.endWalk();
    slowRead!.complete(5000);
    await pending;
    await c.settled;
    slowRead = null;
    expect(c.pet.lastStepTotal, 6500);
    stepTotal = 6500;
    final again = await reopen(c, const Duration(minutes: 1));
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
