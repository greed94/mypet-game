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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 26, 14);
    stepTotal = null;
  });
  // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> make({Duration away = Duration.zero}) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(lastSeenAt: now.subtract(away));
    await db.savePet(pet);
    return PetController(
      db,
      pet,
      readStepTotal: () async => stepTotal,
      random: Random(1),
      clock: () => now,
    );
  }

  Future<PetController> reopen(PetController old, Duration later) async {
    old.sleepApp();
    await pumpEventQueue();
    now = now.add(later);
    final c = PetController(
      db,
      (await db.loadPet())!,
      readStepTotal: () async => stepTotal,
      random: Random(2),
      clock: () => now,
    );
    c.wake();
    await c.collected;
    return c;
  }

  test('걸음을 처음 읽으면 기준만 잡고 환영 선물 하나를 물고 온다', () async {
    stepTotal = 5000;
    final c = await make();
    c.wake();
    await c.collected;
    expect(c.carried, hasLength(1));
    expect(c.carried.single.gift, isTrue);
    expect((await db.loadPet())!.lastStepTotal, 5000);
    expect(c.pet.likeTaste, isNotNull);
    expect(c.pet.likeTaste, isNot(c.pet.dislikeTaste));
  });

  test('다음에 열면 그동안 걸은 걸음만큼 줍고, 하루 상한을 지킨다', () async {
    stepTotal = 5000;
    var c = await make();
    c.wake();
    await c.collected;
    while (c.carried.isNotEmpty) {
      await c.receive();
    }

    stepTotal = 8200;
    c = await reopen(c, const Duration(minutes: 30));
    expect(c.carried.where((i) => i.source == FindSource.pocket), hasLength(2));

    stepTotal = 60000;
    c = await reopen(c, const Duration(minutes: 30));
    expect(
      c.carried.where((i) => i.source == FindSource.pocket),
      hasLength(2 + 3),
    );

    stepTotal = 90000;
    c = await reopen(c, const Duration(minutes: 30));
    expect(
      c.carried.where((i) => i.source == FindSource.pocket),
      hasLength(pocketPerDay),
    );
  });

  test('걸음 권한이 없으면 주머니 걸음은 건너뛴다', () async {
    final c = await make();
    c.wake();
    await c.collected;
    expect(c.carried, isEmpty);
    expect((await db.loadPet())!.lastStepTotal, isNull);
  });

  test('받으면 도감에 들어가고 물고 있던 게 줄어든다', () async {
    stepTotal = 5000;
    final c = await make();
    c.wake();
    await c.collected;
    final id = c.carried.single.itemId;
    final r = (await c.receive())!;
    expect(r.item.id, id);
    expect(r.count, 1);
    expect(r.gift, isTrue);
    expect(c.carried, isEmpty);
    expect(c.finds[id]!.count, 1);
    expect(c.finds[id]!.giftCount, 1);
    expect(await db.allCarried(), isEmpty);
    await pumpEventQueue();
    expect((await db.eventsOn(now)).map((e) => e.kind), contains('find'));
  });

  test('낮잠 자다가 물고 있던 걸 받아 가면 깨서 반응한다', () async {
    stepTotal = 5000;
    final c = await make();
    c.wake();
    await c.collected;
    c.step = const PetStep(Behavior.sleep, 30);
    await c.receive();
    expect(c.step.behavior, isNot(Behavior.sleep));
  });

  test('밤 11시 넘어 열면 창틀에 하나, 같은 밤에는 다시 안 떨어진다', () async {
    now = DateTime(2026, 9, 26, 23, 20);
    var c = await make();
    c.wake();
    await c.collected;
    expect(c.carried, hasLength(1));
    expect(c.carried.single.source, FindSource.window);
    expect(itemById(c.carried.single.itemId)!.pool, ItemPool.night);
    await c.receive();

    c = await reopen(c, const Duration(hours: 2));
    expect(c.carried, isEmpty);
  });

  test('오래 비웠다 오면 하루 한 번 선물을 가져온다', () async {
    final c = await make(away: const Duration(hours: 13));
    c.wake();
    await c.collected;
    expect(c.carried.where((i) => i.gift), hasLength(1));
  });

  test('물고 온 게 있으면 문 앞에서 들고 들어와 앉는다', () async {
    stepTotal = 5000;
    final c = await make();
    c.wake();
    await c.collected;
    expect(c.step.behavior, Behavior.waitAtDoor);
  });

  test('산책을 마치면 주운 걸 물고 들어온다', () async {
    final c = await make();
    c.wake();
    await c.collected;
    c.startWalk();
    c.updateWalkSteps(1800);
    now = now.add(const Duration(minutes: 20));
    final r = c.endWalk();
    expect(r.finds, walkFinds(1800, const Duration(minutes: 20)));
    await pumpEventQueue();
    expect(
      c.carried.where((i) => i.source == FindSource.walk),
      hasLength(r.finds),
    );
  });

  test('모양을 바꾸면 그림을 다시 읽고, 다시 열어도 그 모양이다', () async {
    final c = await make();
    c.wake();
    await c.collected;
    final version = c.spriteVersion;
    c.changeShape('maltese');
    expect(c.spriteVersion, version + 1);
    c.changeShape('maltese');
    expect(c.spriteVersion, version + 1);
    final again = await reopen(c, const Duration(minutes: 5));
    expect(again.pet.shape, 'maltese');
  });

  test('방 칸에 놓은 물건은 저장되고 다시 열어도 남는다', () async {
    final c = await make();
    c.wake();
    await c.collected;
    await c.place('floor1', 'acorn');
    await c.place('sill1', 'moon_piece');
    await c.place('sill1', null);
    expect(c.placed, {'floor1': 'acorn'});
    final again = await reopen(c, const Duration(minutes: 5));
    expect(again.placed, {'floor1': 'acorn'});
  });
}
