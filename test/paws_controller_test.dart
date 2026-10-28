import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/paws.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

void main() {
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

  /// [age]만큼 함께한 펫. [paws]로 발도장을 쥐여 줄 수 있다.
  Future<PetController> make({
    Duration age = const Duration(days: 3),
    int paws = 0,
  }) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(age),
    );
    pet = pet.copyWith(lastSeenAt: now, paws: paws);
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
    return c;
  }

  test('산책 22분이면 발도장 넷, 화면에 "+4"를 알린다', () async {
    final c = await make();
    final gen = c.pawToastGen;
    expect(c.startWalk(), isTrue);
    now = now.add(const Duration(minutes: 22));
    c.endWalk();
    expect(c.paws, 4);
    expect(c.pawToast, 4);
    expect(c.pawToastGen, gen + 1);
    await pumpEventQueue(times: 20);
    expect((await db.loadPet())!.paws, 4);
  });

  test('하루 몫(열)을 넘기지 않고, 펫의 하루가 바뀌면 다시 번다', () async {
    final c = await make();
    for (var i = 0; i < 3; i++) {
      c.startWalk();
      now = now.add(const Duration(minutes: 40));
      c.endWalk();
    }
    expect(c.paws, pawsDailyCap);
    // 새벽 4시는 아직 같은 하루.
    now = DateTime(2026, 10, 7, 4);
    c.startWalk();
    now = now.add(const Duration(minutes: 30));
    c.endWalk();
    expect(c.paws, pawsDailyCap);
    now = DateTime(2026, 10, 7, 9);
    c.startWalk();
    now = now.add(const Duration(minutes: 10));
    c.endWalk();
    expect(c.paws, pawsDailyCap + 2);
  });

  test('개인기를 처음 배운 날은 이정표(하루 몫 밖), 두 번은 안 준다', () async {
    final c = await make();
    c.tricks[Trick.sit] = const TrickProgress(
      attempts: 2,
      successes: 2,
      days: 1,
    );
    // 하루 몫을 먼저 다 채운다.
    for (var i = 0; i < 2; i++) {
      c.startWalk();
      now = now.add(const Duration(minutes: 40));
      c.endWalk();
    }
    expect(c.paws, pawsDailyCap);
    // 세 번째 해내기(misses 2면 꼭 해낸다)로 배운다.
    c.step = const PetStep(Behavior.idle, 3);
    for (var i = 0; i < 3 && !(c.tricks[Trick.sit]?.learned ?? false); i++) {
      c.command(Trick.sit);
    }
    expect(c.tricks[Trick.sit]?.learned, isTrue);
    expect(c.paws, pawsDailyCap + trickMilestonePaws);
    for (var i = 0; i < 3; i++) {
      c.command(Trick.sit);
    }
    expect(c.paws, pawsDailyCap + trickMilestonePaws);
  });

  test('저녁(새벽 5시 전까지)에 처음 말을 걸면 하루 한 번 하나', () async {
    final c = await make();
    await c.talk('안녕');
    expect(c.paws, 0);
    now = DateTime(2026, 10, 6, 19);
    await c.talk('오늘 힘들었어');
    expect(c.paws, eveningTalkPaws);
    await c.talk('잘 자');
    // 자정 넘어 새벽 1시도 같은 펫의 하루다.
    now = DateTime(2026, 10, 7, 1);
    await c.talk('아직 안 자?');
    expect(c.paws, eveningTalkPaws);
    // 다음 날 저녁엔 또.
    now = DateTime(2026, 10, 7, 20);
    await c.talk('다녀왔어');
    expect(c.paws, eveningTalkPaws * 2);
  });

  test(
    '오래 비웠다 와서 7일·30일을 한꺼번에 넘기면 발도장은 다 받고, "+15"로 보이고, 일기엔 30일 하나',
    () async {
      final c = await make(age: const Duration(days: 31));
      final both = togetherMilestones[7]! + togetherMilestones[30]!;
      expect(c.paws, both);
      expect(c.pawToast, both);
      await pumpEventQueue(times: 20);
      final events = await db.eventsOn(now);
      expect(events.where((e) => e.kind == 'together').map((e) => e.detail), [
        '주인이랑 함께한 지 30일이 됐다',
      ]);
    },
  );

  test('산책 끝내기를 두 번 눌러도 한 번만 받는다', () async {
    final c = await make();
    c.startWalk();
    now = now.add(const Duration(minutes: 22));
    final first = c.endWalk();
    expect(first.minutes, 22);
    final again = c.endWalk();
    expect(again.minutes, 0);
    expect(c.paws, 4);
  });

  test('함께한 지 7일이 되면 이정표, 다시 열어도 한 번만', () async {
    final c = await make(age: const Duration(days: 8));
    expect(c.paws, togetherMilestones[7]);
    await pumpEventQueue(times: 20);
    final events = await db.eventsOn(now);
    expect(events.where((e) => e.kind == 'together').map((e) => e.detail), [
      '주인이랑 함께한 지 7일이 됐다',
    ]);
    final again = PetController(db, c.pet, random: Random(2), clock: () => now);
    again.wake();
    await again.collected;
    expect(again.paws, togetherMilestones[7]);
  });

  test('모자라면 못 바꾸고, 바꾸면 발도장이 줄고 바로 쓴다. 가진 건 다시 돈 들지 않는다', () async {
    final c = await make(paws: 10);
    expect(c.buyCosmetic('rug_mint'), isFalse);
    expect(c.paws, 10);
    final version = c.spriteVersion;
    expect(c.buyCosmetic('collar_sky'), isTrue);
    expect(c.paws, 2);
    expect(c.collar.id, 'collar_sky');
    expect(c.pet.accent, 0xFF4FA3D1);
    expect(c.spriteVersion, version + 1);
    expect(c.buyCosmetic('collar_red'), isTrue);
    expect(c.paws, 2);
    expect(c.buyCosmetic('collar_sky'), isTrue);
    expect(c.paws, 2);
    expect(c.buyCosmetic('nope'), isFalse);

    // 다시 열어도 남는다.
    await pumpEventQueue(times: 20);
    final again = PetController(db, c.pet, random: Random(2), clock: () => now);
    expect(again.paws, 2);
    expect(again.ownedCosmetics, containsAll(['collar_sky', 'collar_red']));
    expect(again.collar.id, 'collar_sky');
  });

  test('방석을 바꾸면 방에 그 색이 깔린다(처음은 라벤더)', () async {
    final c = await make(paws: 20);
    expect(c.rug.id, 'rug_lavender');
    expect(c.buyCosmetic('rug_peach'), isTrue);
    expect(c.rug.id, 'rug_peach');
    expect(c.rug.colors, cosmeticById('rug_peach')!.colors);
    c.wearCosmetic('rug_lavender');
    expect(c.rug.id, 'rug_lavender');
    // 안 가진 건 못 쓴다.
    c.wearCosmetic('rug_sky');
    expect(c.rug.id, 'rug_lavender');
  });

  test('들어준 소원과 발표회 도장도 발도장이 된다', () async {
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
      wish: const Value('cuddle'),
      wishDay: Value(dayKey(petDate(now))),
    );
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(seconds: 5));
      c.interact(Interaction.pet);
    }
    expect(c.openWish, isNull);
    expect(c.paws, wishPaws);
  });
}
