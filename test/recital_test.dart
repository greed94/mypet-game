import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/paws.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/recital.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/tricks.dart';

/// 늘 같은 값을 내는 주사위.
class _Fixed implements Random {
  _Fixed(this.v);

  final double v;

  @override
  double nextDouble() => v;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

const _learned = TrickProgress(
  attempts: 3,
  successes: 3,
  days: 1,
  lastDay: '2026-10-08',
  learnedDay: '2026-10-08',
);

void main() {
  test('발표회 상태는 다시 읽히고 잘못된 값은 현재 상태를 덮지 않는다', () {
    const stats = PetStats(mood: 70, hunger: 20, energy: 90, affection: 40);
    final restored = parseRecitalStats(recitalStatsTo(stats))!;
    expect(restored.mood, 70);
    expect(restored.hunger, 20);
    expect(restored.energy, 90);
    expect(restored.affection, 40);
    for (final saved in [
      null,
      '',
      '1,2,3',
      '1,2,3,4,5',
      'NaN,2,3,4',
      '-1,2,3,4',
      '1,101,3,4',
    ]) {
      expect(parseRecitalStats(saved), isNull);
    }
  });
  group('규칙', () {
    test('발표회는 배운 개인기를 별·해낸 횟수 순으로 셋까지, 물어와는 뺀다', () {
      final tricks = {
        Trick.sit: _learned,
        Trick.fetch: const TrickProgress(attempts: 9, successes: 9, days: 3),
        Trick.spin: const TrickProgress(attempts: 6, successes: 5, days: 3),
        Trick.jump: const TrickProgress(attempts: 6, successes: 5, days: 2),
        Trick.down: const TrickProgress(attempts: 4, successes: 4, days: 2),
        Trick.wait: const TrickProgress(attempts: 2, successes: 2, days: 1),
      };
      expect(recitalSet(tricks), [Trick.spin, Trick.jump, Trick.down]);
      expect(recitalSet(const {}), isEmpty);
      expect(recitalSet({Trick.fetch: tricks[Trick.fetch]!}), isEmpty);
    });

    test('차례는 무대로 나가 잇달아 하고 도장으로 끝난다. 못 한 건 갸웃하고 넘어간다', () {
      final steps = recitalSteps(const [
        (Trick.sit, true),
        (Trick.spin, false),
      ]);
      expect(steps.first.targetX, 0.5);
      expect(steps.last.tag, StepTag.stamp);
      expect(steps.where((s) => s.tag == StepTag.stamp), hasLength(1));
      expect(steps.map((s) => s.thought), contains('어… 뭐였더라?'));
      expect(steps.map((s) => s.behavior), isNot(contains(Behavior.spin)));
      for (final s in steps) {
        expect((s.thought ?? '').length, lessThanOrEqualTo(40));
      }
    });

    test('금요일은 펫의 하루로 센다(새벽 5시 전은 아직 목요일)', () {
      expect(recitalDay(DateTime(2026, 10, 9, 10)), isTrue);
      expect(recitalDay(DateTime(2026, 10, 9, 4)), isFalse);
      expect(recitalDay(DateTime(2026, 10, 8, 10)), isFalse);
      expect(parseStamps(null), isEmpty);
      expect(parseStamps('2026-10-02,2026-10-09'), hasLength(2));
    });

    test('배운 날은 세 번째로 해낸 날에만 적고, 기록 전에 배운 개인기엔 오늘을 붙이지 않는다', () {
      var p = const TrickProgress();
      p = p.practiced(success: true, today: '2026-10-01');
      p = p.practiced(success: true, today: '2026-10-01');
      expect(p.learnedDay, isNull);
      p = p.practiced(success: true, today: '2026-10-02');
      expect(p.learnedDay, '2026-10-02');
      p = p.practiced(success: true, today: '2026-10-05');
      expect(p.learnedDay, '2026-10-02');
      const old = TrickProgress(attempts: 5, successes: 4, days: 2);
      expect(
        old.practiced(success: true, today: '2026-10-05').learnedDay,
        isNull,
      );
    });

    test('수첩 한 줄: 안 해 봄, 배우는 중, 배움(오늘 했는지에 따라 다음 별 안내)', () {
      const today = '2026-10-09';
      expect(
        notebookLine(Trick.sit, const TrickProgress(), today: today),
        '놀이 칸에서 시켜 보세요',
      );
      expect(
        notebookLine(Trick.name, const TrickProgress(), today: today),
        contains('이름을 불러'),
      );
      expect(
        notebookLine(Trick.potty, const TrickProgress(), today: today),
        contains('패드'),
      );
      expect(
        notebookLine(
          Trick.sit,
          const TrickProgress(attempts: 3, successes: 2, days: 1),
          today: today,
        ),
        '해낸 2번 · 3번 해내면 배워요',
      );
      expect(
        notebookLine(Trick.sit, _learned, today: today),
        '10월 8일에 배웠어요 · 오늘 하면 별 하나 더',
      );
      expect(
        notebookLine(
          Trick.sit,
          const TrickProgress(
            attempts: 4,
            successes: 4,
            days: 1,
            lastDay: today,
          ),
          today: today,
        ),
        '배웠어요 · 내일 또 하면 별 하나 더',
      );
      expect(
        notebookLine(
          Trick.sit,
          const TrickProgress(
            attempts: 9,
            successes: 9,
            days: 3,
            lastDay: today,
          ),
          today: today,
        ),
        contains('별 셋'),
      );
      expect(monthDay('2026-10-01'), '10월 1일');
    });

    test('도장 받은 날은 폰이 쓰는 일기에도 들어간다', () {
      final text = localDiary([
        (at: DateTime(2026, 10, 9, 10), kind: 'feed', detail: '주인이 밥을 줬다'),
        (
          at: DateTime(2026, 10, 9, 11),
          kind: 'recital',
          detail: "유치원 발표회에서 친구들 앞에 '앉아'를 보여 주고 도장을 받았다",
        ),
      ], Random(1))!;
      expect(text, contains('발표회'));
    });

    test('맡겨 둔 발표회는 금요일 3시 전에 맡겼고 3시가 지났을 때만', () {
      final fri9 = DateTime(2026, 10, 9, 9);
      expect(daycareRecitalHeld(fri9, DateTime(2026, 10, 9, 15)), isTrue);
      expect(daycareRecitalHeld(fri9, DateTime(2026, 10, 9, 14, 59)), isFalse);
      expect(
        daycareRecitalHeld(
          DateTime(2026, 10, 9, 15, 20),
          DateTime(2026, 10, 9, 18),
        ),
        isFalse,
      );
      expect(
        daycareRecitalHeld(DateTime(2026, 10, 8, 9), DateTime(2026, 10, 8, 18)),
        isFalse,
      );
    });
  });

  group('컨트롤러', () {
    late AppDatabase db;
    // 2026-10-09는 금요일이다.
    var now = DateTime(2026, 10, 9, 10);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 9, 10);
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
      pet = pet.copyWith(lastSeenAt: now);
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 70);
      c.tricks[Trick.sit] = _learned;
      return c;
    }

    /// 걷기는 닿으면, 나머지는 시간이 지나면 다음으로. 도장 단계까지 간다.
    void playUntilStamp(PetController c) {
      for (var i = 0; i < 60 && c.step.tag != StepTag.stamp; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(c.step.seconds + 0.01);
        }
      }
    }

    test('금요일에 유치원을 구경하면 발표회를 하고, 끝까지 하면 연습으로 치고 도장을 받는다', () async {
      final c = await make();
      expect(c.recitalReady, isFalse);
      expect(c.goToKindergarten(), isTrue);
      expect(c.recitalReady, isTrue);
      final gen = c.recitalGen;
      expect(c.startRecital(), isTrue);
      expect(c.recitalGen, gen + 1);
      expect(c.recitalOn, isTrue);
      expect(c.recitalReady, isFalse);
      // 끝나기 전엔 아무것도 남지 않는다.
      expect(c.tricks[Trick.sit]?.attempts, 3);
      expect(c.recitalStamps, isEmpty);
      final cheer = c.cheerGen;
      playUntilStamp(c);
      expect(c.step.tag, StepTag.stamp);
      expect(c.cheerGen, cheer + 1);
      expect(c.recitalStamps, ['2026-10-09']);
      expect(c.recitalStampedToday, isTrue);
      expect(c.tricks[Trick.sit]?.attempts, 4);
      expect(c.tricks[Trick.sit]?.days, 2);
      await pumpEventQueue(times: 20);
      final events = await db.eventsOn(now);
      expect(
        events.where((e) => e.kind == 'recital').single.detail,
        "유치원 발표회에서 친구들 앞에 '앉아'를 보여 주고 도장을 받았다",
      );
      expect((await db.loadTricks())[Trick.sit]?.attempts, 4);
      // tick은 한 번에 1초까지만 흐른다.
      for (var i = 0; i < 4; i++) {
        c.tick(1);
      }
      expect(c.recitalOn, isFalse);
      expect(c.recitalReady, isFalse);
      // 다시 열어도 도장은 남는다.
      expect((await db.loadPet())!.recitalDays, '2026-10-09');
    });

    Future<List<DayEvent>> recitals() async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == 'recital') (at: e.at, kind: e.kind, detail: e.detail),
    ];

    test('금요일에 맡기면 3시에 CCTV 속에서 발표회를 하고, 하원해도 도장은 하나', () async {
      now = DateTime(2026, 10, 9, 9);
      final c = await make();
      c.goToKindergarten();
      expect(c.dropOff(), isTrue);
      expect(c.daycareRecitalPlanned, isTrue);
      now = DateTime(2026, 10, 9, 15, 0, 30);
      // 맡길 때의 동작이 끝나고 다음 동작을 고를 때 시작한다.
      for (var i = 0; i < 20 && c.step.thought != '오늘은 발표회!'; i++) {
        c.tick(1);
      }
      expect(c.step.thought, '오늘은 발표회!');
      expect(c.recitalOn, isTrue);
      playUntilStamp(c);
      expect(c.recitalStamps, ['2026-10-09']);
      expect(c.daycareRecitalPlanned, isFalse);
      now = DateTime(2026, 10, 9, 17);
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(c.recitalStamps, ['2026-10-09']);
      expect(await recitals(), hasLength(1));
    });

    test('3시에 못 봤으면 하원할 때 하고 온 것으로 친다(일기 시각은 3시)', () async {
      now = DateTime(2026, 10, 9, 9);
      final c = await make();
      c.goToKindergarten();
      c.dropOff();
      now = DateTime(2026, 10, 9, 15, 30);
      final seen = <String?>[];
      for (var i = 0; i < 20; i++) {
        c.tick(1);
        seen.add(c.step.thought);
      }
      expect(seen, isNot(contains('오늘은 발표회!')));
      now = DateTime(2026, 10, 9, 17);
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(c.recitalStamps, ['2026-10-09']);
      expect(c.tricks[Trick.sit]?.attempts, 4);
      expect((await recitals()).single.at, DateTime(2026, 10, 9, 15));
    });

    test('버스로 온 다음 날 열어도 어제 일기에 발표회가 들어가고, 오늘 하루 몫은 그대로다', () async {
      now = DateTime(2026, 10, 9, 9);
      final c = await make();
      await db.saveTrick(Trick.sit, _learned);
      c.goToKindergarten();
      c.dropOff();
      c.sleepApp();
      await pumpEventQueue();
      now = DateTime(2026, 10, 10, 8);
      final later = PetController(
        db,
        (await db.loadPet())!,
        random: Random(2),
        clock: () => now,
      );
      later.wake();
      await later.collected;
      await pumpEventQueue(times: 100);
      expect(later.recitalStamps, ['2026-10-09']);
      expect((await db.allDiaries()).single.content, contains('발표회'));
      expect(later.pet.paws, recitalPaws);
      expect(later.pet.pawsToday, 0);
    });

    test('못 본 발표회를 다음 날 아침에 처리해도 밤새 배고픈 지금이 아니라 3시 상태로 해낸다', () async {
      now = DateTime(2026, 10, 9, 9);
      final c = await make();
      await db.saveTrick(Trick.sit, _learned);
      c.goToKindergarten();
      c.dropOff();
      c.sleepApp();
      await pumpEventQueue();
      now = DateTime(2026, 10, 10, 9);
      final later = PetController(
        db,
        (await db.loadPet())!,
        random: _Fixed(0.78),
        clock: () => now,
      );
      later.wake();
      await later.collected;
      await pumpEventQueue(times: 100);
      // 지금은 배가 고파 이 주사위면 틀릴 상태다. 3시엔 점심을 먹고 배가 불렀다.
      expect(later.stats.hunger, greaterThan(75));
      expect(later.tricks[Trick.sit]!.successes, _learned.successes + 1);
    });

    for (final minute in [5, 30]) {
      test('금요일 15:$minute에 열었다 닫고 다음 날 재시작해도 발표회는 3시 상태로 한다', () async {
        now = DateTime(2026, 10, 9, 9);
        final c = await make();
        await db.saveTrick(Trick.sit, _learned);
        c.goToKindergarten();
        c.dropOff();
        c.sleepApp();
        await c.settled;
        now = DateTime(2026, 10, 9, 15, minute);
        final afternoon = PetController(
          db,
          (await db.loadPet())!,
          random: _Fixed(0.78),
          clock: () => now,
        );
        afternoon.wake();
        await afternoon.settled;
        afternoon.sleepApp();
        await afternoon.settled;
        afternoon.dispose();
        now = DateTime(2026, 10, 10, 9);
        final nextDay = PetController(
          db,
          (await db.loadPet())!,
          random: _Fixed(0.78),
          clock: () => now,
        );
        nextDay.wake();
        await nextDay.settled;
        expect(nextDay.stats.hunger, greaterThan(75));
        expect(nextDay.tricks[Trick.sit]!.successes, _learned.successes + 1);
        expect(nextDay.pet.daycareRecitalStats, isNull);
        final events = await db.eventsOn(DateTime(2026, 10, 9, 15));
        expect(events.where((e) => e.kind == 'recital'), hasLength(1));
        nextDay.dispose();
        c.dispose();
      });
    }

    test('켜 둔 채 발표회를 시작했다 끊고 재시작해도 발표회 시작 상태를 쓴다', () async {
      now = DateTime(2026, 10, 9, 9);
      final c = await make();
      await db.saveTrick(Trick.sit, _learned);
      c.goToKindergarten();
      c.dropOff();
      now = DateTime(2026, 10, 9, 15, 0, 30);
      for (var i = 0; i < 20 && !c.recitalOn; i++) {
        c.tick(1);
      }
      expect(c.recitalOn, isTrue);
      expect(c.pet.daycareRecitalStats, isNotNull);
      expect(c.recitalStamps, isEmpty);
      c.sleepApp();
      await c.settled;
      c.dispose();
      now = DateTime(2026, 10, 10, 9);
      final later = PetController(
        db,
        (await db.loadPet())!,
        random: _Fixed(0.78),
        clock: () => now,
      );
      later.wake();
      await later.settled;
      expect(later.tricks[Trick.sit]!.successes, _learned.successes + 1);
      expect(later.pet.daycareRecitalStats, isNull);
      expect(later.recitalStamps, ['2026-10-09']);
      later.dispose();
    });

    test('금요일이 아니거나, 3시가 지나 맡겼거나, 이미 구경 가서 도장을 받았으면 맡겨도 발표회가 없다', () async {
      now = DateTime(2026, 10, 8, 9);
      final thu = await make();
      thu.goToKindergarten();
      thu.dropOff();
      expect(thu.daycareRecitalPlanned, isFalse);
      now = DateTime(2026, 10, 8, 17);
      thu.pickUp();
      await pumpEventQueue(times: 50);
      expect(thu.recitalStamps, isEmpty);

      now = DateTime(2026, 10, 9, 15, 20);
      thu.goToKindergarten();
      thu.dropOff();
      expect(thu.daycareRecitalPlanned, isFalse);
      now = DateTime(2026, 10, 9, 18);
      thu.pickUp();
      await pumpEventQueue(times: 50);
      expect(thu.recitalStamps, isEmpty);
    });

    test('구경 가서 도장을 받은 날 맡겨도 두 번 하지 않는다', () async {
      final c = await make();
      c.goToKindergarten();
      c.startRecital();
      playUntilStamp(c);
      expect(c.recitalStamps, ['2026-10-09']);
      now = DateTime(2026, 10, 9, 11);
      c.dropOff();
      expect(c.daycareRecitalPlanned, isFalse);
      now = DateTime(2026, 10, 9, 15, 1);
      final seen = <String?>[];
      for (var i = 0; i < 20; i++) {
        c.tick(1);
        seen.add(c.step.thought);
      }
      expect(seen, isNot(contains('오늘은 발표회!')));
      now = DateTime(2026, 10, 9, 17);
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(await recitals(), hasLength(1));
    });

    test('중간에 쓰다듬어 끊기면 도장도 연습 기록도 남지 않고, 다시 할 수 있다', () async {
      final c = await make();
      c.goToKindergarten();
      c.startRecital();
      c.arrived();
      c.interact(Interaction.pet);
      expect(c.recitalOn, isFalse);
      for (var i = 0; i < 40; i++) {
        c.tick(1);
      }
      expect(c.recitalStamps, isEmpty);
      expect(c.tricks[Trick.sit]?.attempts, 3);
      expect(c.recitalReady, isTrue);
    });

    test('집에 가 버리면 도장은 없다', () async {
      final c = await make();
      c.goToKindergarten();
      c.startRecital();
      c.comeHome();
      expect(c.spot, Spot.home);
      expect(c.recitalOn, isFalse);
      for (var i = 0; i < 40; i++) {
        c.tick(1);
      }
      expect(c.recitalStamps, isEmpty);
    });

    test('금요일이 아니거나, 낮잠 시간이거나, 맡겨 뒀거나, 배운 게 없거나, 지쳤으면 발표회는 없다', () async {
      now = DateTime(2026, 10, 8, 10);
      final thursday = await make();
      thursday.goToKindergarten();
      expect(thursday.recitalReady, isFalse);
      thursday.comeHome();

      now = DateTime(2026, 10, 9, 13, 10);
      expect(thursday.goToKindergarten(), isTrue);
      expect(thursday.recitalReady, isFalse);
      thursday.comeHome();

      now = DateTime(2026, 10, 9, 10);
      thursday.goToKindergarten();
      expect(thursday.recitalReady, isTrue);
      expect(thursday.dropOff(), isTrue);
      expect(thursday.recitalReady, isFalse);
      expect(thursday.startRecital(), isFalse);
    });

    test('문 닫기·낮잠 1분 전부터는 발표회를 띄우지 않는다(하다가 끊기면 도장이 없다)', () async {
      now = DateTime(2026, 10, 9, 18, 58);
      final c = await make();
      c.goToKindergarten();
      expect(c.recitalReady, isTrue);
      now = DateTime(2026, 10, 9, 18, 59, 30);
      expect(c.recitalReady, isFalse);
      c.comeHome();
      now = DateTime(2026, 10, 9, 12, 59, 30);
      c.goToKindergarten();
      expect(c.recitalReady, isFalse);
      now = DateTime(2026, 10, 9, 12, 58);
      expect(c.recitalReady, isTrue);
    });

    test('배운 게 없으면 발표회는 없고, 지쳤으면 쉬고 싶다고 한다', () async {
      final c = await make();
      c.tricks.clear();
      c.goToKindergarten();
      expect(c.recitalReady, isFalse);
      c.tricks[Trick.sit] = _learned;
      expect(c.recitalReady, isTrue);
      c.stats = c.stats.copyWith(energy: 5);
      expect(c.startRecital(), isFalse);
      expect(c.recitalOn, isFalse);
    });
  });
}
