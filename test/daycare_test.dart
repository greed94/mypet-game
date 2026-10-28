import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/tricks.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 10, 5, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 5, 9);
  });
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> make() async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    pet = pet.copyWith(lastSeenAt: now, affection: 40);
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    return c;
  }

  Greeting? greeted;

  Future<PetController> reopen(PetController old, Duration later) async {
    old.sleepApp();
    await pumpEventQueue();
    now = now.add(later);
    final c = PetController(
      db,
      (await db.loadPet())!,
      random: Random(2),
      clock: () => now,
    );
    greeted = c.wake();
    await c.collected;
    return c;
  }

  Future<List<String>> events(String kind) async => [
    for (final e in await db.eventsOn(now))
      if (e.kind == kind) e.detail,
  ];

  test('유치원은 문 연 시간에만 들어가고, 맡기는 건 오후 5시 전까지다', () async {
    final c = await make();
    now = DateTime(2026, 10, 5, 19, 30);
    expect(c.goToKindergarten(), isFalse);
    expect(c.out, isFalse);

    now = DateTime(2026, 10, 5, 17, 10);
    expect(c.goToKindergarten(), isTrue);
    expect(c.spot, Spot.kindergarten);
    expect(c.guests.length, 3);
    expect(c.dropOff(), isFalse);
    expect(c.inDaycare, isFalse);
  });

  test('맡기면 유치원에 남고, 그사이 열면 반김 없이 유치원 CCTV다', () async {
    final c = await make();
    expect(c.goToKindergarten(), isTrue);
    expect(c.dropOff(), isTrue);
    expect(c.inDaycare, isTrue);
    expect(c.bubble, '금방 와야 해!');
    expect(await events('daycare_drop'), hasLength(1));

    final later = await reopen(c, const Duration(hours: 4));
    expect(greeted, Greeting.none);
    expect(later.inDaycare, isTrue);
    expect(later.spot, Spot.kindergarten);
    expect(later.guests.length, 3);
    expect(later.step.behavior, isNot(Behavior.waitAtDoor));
    // 점심을 먹어 집에 혼자 있던 것보다 배가 덜 고프다.
    expect(later.stats.hunger, lessThan(40));
  });

  test('하원 시간이 지나 열면 버스로 집에 와 있고, 반김은 집에 혼자 있던 시간만큼만 한다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    final later = await reopen(c, const Duration(hours: 11)); // 저녁 8시
    expect(later.inDaycare, isFalse);
    expect(later.spot, Spot.home);
    expect((await db.loadPet())!.daycareFrom, isNull);
    final done = await events('daycare');
    expect(done.single, contains('버스'));
    // 하루 종일 비웠지만 집에 혼자 있던 건 한 시간이라 크게 반기지 않는다(맡기지 않았으면 big).
    expect(greeted, Greeting.hello);
    // 쉬는 유치원에서 하고 왔다.
    expect((await db.loadPet())!.pottyAt, DateTime(2026, 10, 5, 19));
  });

  test('데리러 가면 집으로 같이 오고, 두 시간 넘게 있었으면 수업을 하나 하고 온다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff(lesson: Trick.sit);
    now = now.add(const Duration(hours: 3));
    c.pickUp();
    expect(c.inDaycare, isFalse);
    expect(c.spot, Spot.home);
    expect(c.bubble, '데리러 왔다!');
    await pumpEventQueue(times: 50);
    expect((await events('daycare')).single, contains('데리러'));
    expect(c.tricks[Trick.sit]?.successes, 1);
    expect((await db.loadTricks())[Trick.sit]?.successes, 1);
    expect(await events('trick'), [contains('유치원에서')]);

    // 같은 날 또 맡겨도 수업은 하루 한 번.
    c.goToKindergarten();
    c.dropOff(lesson: Trick.sit);
    now = now.add(const Duration(hours: 3));
    c.pickUp();
    await pumpEventQueue(times: 50);
    expect(c.tricks[Trick.sit]?.successes, 1);
  });

  test('하원 다음 날 처음 열면 어제 일기에 버스 하원과 수업이 다 들어가고, 반김 문장은 혼자 있던 시간만 센다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff(lesson: Trick.sit);
    // 다음 날 아침 8시: 하원(어제 19시) 뒤 13시간 혼자 있었다. 맡긴 때부터는 23시간.
    final later = await reopen(c, const Duration(hours: 23));
    await pumpEventQueue(times: 100);
    final diary = (await db.allDiaries()).single;
    expect(diary.content, contains('버스'));
    expect(diary.content, contains('유치원에서'));
    expect(diary.content, contains("'앉아'"));
    final greets = [
      for (final e in await db.eventsOn(now))
        if (e.kind == 'greet') e.detail,
    ];
    expect(greets.single, contains('13시간'));
    expect(later.spot, Spot.home);
  });

  test('잠깐 맡겼다 찾으면 수업은 없다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    now = now.add(const Duration(minutes: 30));
    c.pickUp();
    await pumpEventQueue(times: 50);
    expect(c.tricks[Trick.sit], isNull);
    expect(await events('trick'), isEmpty);
  });

  test('수업은 주인이 한 연습 기록을 덮지 않는다', () async {
    await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    await db.saveTrick(
      Trick.down,
      const TrickProgress(attempts: 4, successes: 2, days: 2, lastDay: 'x'),
    );
    final pet = (await db.loadPet())!.copyWith(
      lastSeenAt: now,
      daycareFrom: Value(now.subtract(const Duration(hours: 3))),
    );
    await db.savePet(pet);
    // 하원 시간이 지난 뒤 처음 여는 순간 수업이 돈다. 개인기를 읽기 전이어도 기록을 덮지 않아야 한다.
    now = DateTime(2026, 10, 5, 20);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    await pumpEventQueue(times: 50);
    final saved = await db.loadTricks();
    expect(saved[Trick.down]?.successes, 3);
    expect(saved[Trick.down]?.attempts, 5);
    expect(c.tricks[Trick.down]?.successes, 3);
  });

  test('시계를 맡긴 때보다 앞으로 돌려도 유치원에 갇히지 않는다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    final later = await reopen(c, const Duration(days: -2));
    expect(later.inDaycare, isFalse);
    expect(later.spot, Spot.home);
  });

  test('CCTV로 보는 중엔 말이 닿지 않고 만져도 친밀도가 오르지 않는다. 위기 안내는 그대로다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    final before = c.stats.affection;
    c.step = const PetStep(Behavior.idle, 3);
    c.interact(Interaction.pet);
    expect(c.bubble, '어? 누가 보고 있나?');
    expect(c.stats.affection, before);
    expect(await c.talk('뭐 해?'), TalkOutcome.away);
    expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
  });

  test('CCTV에 대고 말을 걸면 소리는 안 가도 펫이 문득 주인 생각을 한다(속마음이 떠 있는 동안은 한 번)', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    c.step = const PetStep(Behavior.idle, 3);
    expect(await c.talk('뭐 해?'), TalkOutcome.away);
    expect(c.step.thought, '…? 문득 주인 생각');
    // 앉기(2.5초)가 끝나도 속마음(5초)이 떠 있는 동안 또 말하면 처음부터 다시 하지 않는다.
    for (var i = 0; i < 3; i++) {
      c.tick(1);
    }
    expect(c.step.behavior, Behavior.happy);
    expect(c.bubble, '…? 문득 주인 생각');
    final elapsed = c.stepElapsed;
    await c.talk('보고 싶어');
    expect(c.step.behavior, Behavior.happy);
    expect(c.stepElapsed, elapsed);
    // 속마음이 사라진 뒤 또 부르면 또 생각한다. 일기 줄은 하루 한 번.
    for (var i = 0; i < 6; i++) {
      c.tick(1);
    }
    expect(c.bubble, isNull);
    await c.talk('잘 있어?');
    expect(c.step.thought, '…? 문득 주인 생각');
    await pumpEventQueue(times: 20);
    expect(await events('daycare_miss'), ['유치원에서 놀다가 문득 주인 생각이 났다']);
    expect(await events('daycare'), isEmpty);

    // 낮잠 중이면 모른다. 화면은 낮잠 중이라고 알려 준다.
    c.step = const PetStep(Behavior.sleep, 30);
    expect(await c.talk('잘 지내?'), TalkOutcome.awayAsleep);
    expect(c.step.behavior, Behavior.sleep);
  });

  test('CCTV로 말을 건 날도 폰 일기에 버스 하원 줄이 빠지지 않는다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff(lesson: Trick.sit);
    c.step = const PetStep(Behavior.idle, 3);
    await c.talk('뭐 해?');
    await reopen(c, const Duration(hours: 23));
    await pumpEventQueue(times: 100);
    final diary = (await db.allDiaries()).single;
    expect(diary.content, contains('버스'));
    expect(diary.content, contains('문득 주인 생각'));
  });

  test('CCTV를 켜 둔 채 저녁 7시가 되면 버스 타고 집에 온다', () async {
    final c = await make();
    c.goToKindergarten();
    c.dropOff();
    now = DateTime(2026, 10, 5, 18, 59, 59);
    c.tick(0.5);
    expect(c.inDaycare, isTrue);
    now = DateTime(2026, 10, 5, 19);
    c.tick(0.5);
    expect(c.inDaycare, isFalse);
    expect(c.spot, Spot.home);
    expect(c.bubble, '버스 타고 왔다!');
  });

  test('맡기지 않고 구경만 하고 오면 그것도 일기 재료다', () async {
    final c = await make();
    c.goToKindergarten();
    now = now.add(const Duration(minutes: 10));
    c.comeHome();
    expect(c.spot, Spot.home);
    await pumpEventQueue();
    expect((await events('daycare')).single, contains('놀러'));
  });
}
