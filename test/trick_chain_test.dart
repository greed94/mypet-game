import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

/// 개인기 이어 하기(아이디어 T5): 잘 익힌(별 셋) 개인기 여럿을 한 말에 시키면 이어서 한다.
void main() {
  group('규칙', () {
    test('한 말에 든 개인기를 순서대로 찾는다(이름·군말·문장부호는 건너뛰고, 잇따른 같은 건 하나)', () {
      expect(parseChain('앉아 엎드려 돌아', '콩이'), [
        Trick.sit,
        Trick.down,
        Trick.spin,
      ]);
      expect(parseChain('콩이야 앉아, 엎드려!', '콩이'), [Trick.sit, Trick.down]);
      expect(parseChain('앉아 앉아', '콩이'), [Trick.sit]);
      expect(parseChain('오늘 날씨 좋다', '콩이'), isEmpty);
    });

    test('띄어 쓴 명령도 잇고, 이름·군말은 건너뛴다', () {
      expect(parseChain('앉아 엎드려 이리 와', '콩이'), [
        Trick.sit,
        Trick.down,
        Trick.come,
      ]);
      expect(parseChain('콩이 앉아 엎드려 해봐', '콩이'), [Trick.sit, Trick.down]);
      expect(parseChain('자 앉아 엎드려요', '콩이'), [Trick.sit, Trick.down]);
    });

    test('개인기 말고 다른 말이 섞이면 이어 하기가 아니다(지친 말·부탁이 묻히지 않게)', () {
      expect(parseChain('앉아 엎드려 너무 힘들어', '콩이'), isEmpty);
      expect(parseChain('앉아 기다려 줘', '콩이'), isEmpty);
    });

    test('폰 일기는 그날 먼저 해 보인 개인기 줄이 있어도 이어 한 줄을 고른다', () {
      final diary = localDiary([
        (
          at: DateTime(2026, 10, 6, 10),
          kind: 'trick',
          detail: "주인 앞에서 '앉아'를 해 보였다",
        ),
        (
          at: DateTime(2026, 10, 6, 11),
          kind: 'trick_chain',
          detail: "'앉아'·'엎드려'를 이어서 해 보였다",
        ),
      ], Random(1))!;
      expect(diary, contains('이어서 해 보였다'));
    });

    test('별 셋이고 물어와가 아니어야 이어서 시킬 수 있다', () {
      const three = TrickProgress(
        attempts: 6,
        successes: 6,
        days: 3,
        lastDay: '2026-10-05',
      );
      const two = TrickProgress(
        attempts: 4,
        successes: 4,
        days: 2,
        lastDay: '2026-10-05',
      );
      expect(chainable(Trick.sit, three), isTrue);
      expect(chainable(Trick.sit, two), isFalse);
      expect(chainable(Trick.fetch, three), isFalse);
      expect(chainable(Trick.sit, null), isFalse);
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

    const three = TrickProgress(
      attempts: 6,
      successes: 6,
      days: 3,
      lastDay: '2026-10-05',
    );

    Future<PetController> make(Map<Trick, TrickProgress> known) async {
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
        quirk: const Value('sniffOwnerAfterGreet'),
        pawMarks: const Value('hidden'),
      );
      await db.savePet(pet);
      for (final MapEntry(key: t, value: p) in known.entries) {
        await db.saveTrick(t, p);
      }
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

    List<Behavior> behaviors(PetController c, int seconds) {
      final seen = <Behavior>[];
      PetStep? last;
      for (var i = 0; i < seconds; i++) {
        if (!identical(c.step, last)) {
          last = c.step;
          seen.add(c.step.behavior);
        }
        c.tick(1);
      }
      return seen;
    }

    test('잘 익힌 개인기 셋을 한 말에 시키면 이어서 하고 끝에 "다 했다!"', () async {
      final c = await make({
        Trick.sit: three,
        Trick.down: three,
        Trick.spin: three,
      });
      expect(await c.talk('앉아 엎드려 돌아'), TalkOutcome.command);
      expect(behaviors(c, 14).take(4), [
        Behavior.sit,
        Behavior.lieBeside,
        Behavior.spin,
        Behavior.happy,
      ]);
      for (final t in [Trick.sit, Trick.down, Trick.spin]) {
        expect(c.tricks[t]!.attempts, three.attempts + 1);
        expect(c.tricks[t]!.days, 4);
      }
      await pumpEventQueue(times: 20);
      expect(await events('trick_chain'), ["'앉아'·'엎드려'·'돌아'를 이어서 해 보였다"]);
    });

    test('하루에 여러 번 이어 해도 일기 줄은 하나다', () async {
      final c = await make({Trick.sit: three, Trick.down: three});
      await c.talk('앉아 엎드려');
      behaviors(c, 12);
      await c.talk('앉아 엎드려');
      await pumpEventQueue(times: 20);
      expect(await events('trick_chain'), hasLength(1));
    });

    test('자다가 시키면 졸린 채로 일어나서 한다', () async {
      final c = await make({Trick.sit: three, Trick.down: three});
      c.step = const PetStep(Behavior.sleep, 30);
      await c.talk('앉아 엎드려');
      expect(c.step.thought, '으응… 졸린데.');
    });

    test('지친 말이 섞이면 개인기를 하지 않고 지친 말을 듣는다', () async {
      final c = await make({Trick.sit: three, Trick.down: three});
      expect(await c.talk('앉아 엎드려 너무 힘들어'), isNot(TalkOutcome.command));
      expect(c.tricks[Trick.sit]!.attempts, three.attempts);
      expect(c.pet.comfortDue, isTrue);
    });

    test('하나라도 덜 익혔으면 처음 것만 한다', () async {
      final c = await make({Trick.sit: three, Trick.down: three});
      await c.talk('앉아 엎드려 돌아');
      expect(c.tricks[Trick.down]!.attempts, three.attempts);
      expect(c.tricks[Trick.sit]!.attempts, three.attempts + 1);
    });

    test('지쳤으면 이어서 하지 않는다', () async {
      final c = await make({Trick.sit: three, Trick.down: three});
      c.stats = c.stats.copyWith(energy: 5);
      await c.talk('앉아 엎드려');
      expect(c.step.thought, '졸려… 나중에 할래.');
      expect(c.tricks[Trick.sit]!.attempts, three.attempts);
    });
  });
}
