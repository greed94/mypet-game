import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/quirks.dart';

void main() {
  group('규칙', () {
    test('같은 펫은 늘 같은 버릇이고, 펫이 많으면 여섯 가지가 다 나온다', () {
      final born = DateTime(2026, 10, 1, 9, 30);
      expect(quirkFor(7, born), quirkFor(7, born));
      final seen = {for (var id = 1; id <= 300; id++) quirkFor(id, born)};
      expect(seen, Quirk.values.toSet());
      for (final q in Quirk.values) {
        expect(quirkLine(q), isNotEmpty);
      }
    });

    test('자기 전 돌기는 제자리에서 방 안쪽으로만 왔다 갔다 하다 제자리에 선다', () {
      for (final x in [0.15, 0.5, 0.85]) {
        final s = circleSteps(x);
        expect(s.last.targetX, x);
        for (final p in s) {
          expect(p.behavior, Behavior.walk);
          expect((p.targetX! - x).abs(), lessThanOrEqualTo(0.05));
          // 방 가운데 쪽으로만 나간다.
          if (x != rugX) {
            expect((p.targetX! - x) * (rugX - x), greaterThanOrEqualTo(0));
          }
        }
      }
      expect(circleSteps(0.85).every((p) => p.targetX! <= 0.85), isTrue);
      expect(circleSteps(0.15).every((p) => p.targetX! >= 0.15), isTrue);
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

    Future<PetController> make(Quirk quirk, {double affection = 50}) async {
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
        affection: affection,
        quirk: Value(quirk.name),
        pawMarks: const Value('hidden'),
      );
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
      c.step = const PetStep(Behavior.idle, 3);
      return c;
    }

    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    /// 1초씩 [seconds]번. 걷기·달리기는 닿은 걸로 친다. 새 동작이 시작될 때마다 [each].
    void follow(
      PetController c,
      int seconds, [
      void Function(PetStep step)? each,
    ]) {
      PetStep? last;
      for (var i = 0; i < seconds; i++) {
        if (!identical(c.step, last)) {
          last = c.step;
          each?.call(c.step);
        }
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
    }

    void feed(PetController c) {
      c.stats = c.stats.copyWith(hunger: 80);
      c.interact(Interaction.feed);
    }

    test('밥 앞에서 앉는 버릇: 앉았다가 먹는다', () async {
      final c = await make(Quirk.sitBeforeEat);
      feed(c);
      expect(c.step.behavior, Behavior.sit);
      c.tick(1);
      c.tick(1);
      expect(c.step.behavior, Behavior.eat);
    });

    test('빈 그릇 킁킁 버릇: 다 먹고 그릇을 킁킁댄다(그 동안 그릇을 그린다)', () async {
      final c = await make(Quirk.sniffBowlAfter);
      feed(c);
      expect(c.step.behavior, Behavior.eat);
      for (var i = 0; i < 3; i++) {
        c.tick(1);
      }
      expect(c.step.behavior, Behavior.sniff);
      expect(c.step.tag, StepTag.bowl);
    });

    test('밥 버릇이 없는 애는 바로 먹고, 다 먹은 뒤 그릇을 맡지 않는다', () async {
      final c = await make(Quirk.hopWhenPetted);
      feed(c);
      expect(c.step.behavior, Behavior.eat);
      for (var i = 0; i < 3; i++) {
        c.tick(1);
      }
      expect(c.step.tag, isNot(StepTag.bowl));
    });

    test('쓰다듬으면 폴짝 버릇: 먼저 한 번 폴짝(소리도 그때), 연달아 문지르면 매번 뛰진 않는다', () async {
      final c = await make(Quirk.hopWhenPetted);
      c.interact(Interaction.pet);
      expect(c.step.behavior, Behavior.jump);
      expect(c.step.cue, Cue.pop);
      c.tick(1);
      expect(c.step.behavior, Behavior.happy);
      c.interact(Interaction.pet);
      expect(c.step.behavior, Behavior.happy);
    });

    test('폴짝 버릇이 없는 애는 쓰다듬으면 바로 좋아한다', () async {
      final c = await make(Quirk.sitBeforeEat);
      c.interact(Interaction.pet);
      expect(c.step.behavior, Behavior.happy);
    });

    test('반긴 뒤 발 냄새 버릇: 한참 비웠다 열면 반김 끝에 말없이 킁킁, 밤엔 안 한다', () async {
      bool sniffsAfterHappy(List<PetStep> steps) {
        for (var i = 1; i < steps.length; i++) {
          if (steps[i].behavior == Behavior.sniff &&
              steps[i].thought == null &&
              steps[i - 1].behavior == Behavior.happy) {
            return true;
          }
        }
        return false;
      }

      final c = await make(Quirk.sniffOwnerAfterGreet);
      c.sleepApp();
      now = now.add(const Duration(hours: 5));
      c.wake();
      final day = <PetStep>[];
      follow(c, 20, day.add);
      expect(sniffsAfterHappy(day), isTrue);

      // 밤엔 졸린 반김 뒤 그대로 잔다(잠 30초 뒤에도 킁킁이 붙지 않는다).
      c.sleepApp();
      now = DateTime(2026, 10, 7, 1);
      c.wake();
      final night = <PetStep>[];
      follow(c, 45, night.add);
      expect(
        night.any((s) => s.behavior == Behavior.sniff && s.thought == null),
        isFalse,
      );
    });

    test('발 냄새 버릇이 없는 애는 반김 끝에 킁킁대지 않는다', () async {
      final c = await make(Quirk.circleBeforeSleep);
      c.sleepApp();
      now = now.add(const Duration(hours: 5));
      c.wake();
      final steps = <PetStep>[];
      follow(c, 20, steps.add);
      expect(
        steps.any((s) => s.behavior == Behavior.sniff && s.thought == null),
        isFalse,
      );
    });

    test('자기 전 돌기 버릇: 잠들기 전에 한 번만 돌아서고(30초마다 돌지 않는다) 제자리에서 잔다', () async {
      final c = await make(Quirk.circleBeforeSleep, affection: 20);
      now = DateTime(2026, 10, 6, 23, 30);
      var walks = 0;
      follow(c, 90, (s) {
        if (s.behavior == Behavior.walk) walks++;
      });
      expect(walks, circleSteps(rugX).length);
      expect(c.step.behavior, Behavior.sleep);
      expect(c.petX, closeTo(rugX, 1e-9));
    });

    test('자리가 멀면 걸어가서 거기서 돈다', () async {
      final c = await make(Quirk.circleBeforeSleep);
      now = DateTime(2026, 10, 6, 23, 30);
      final targets = <double?>[];
      follow(c, 40, (s) {
        if (s.behavior == Behavior.walk) targets.add(s.targetX);
      });
      const spot = doorX + 0.06;
      expect(targets.first, closeTo(spot, 1e-9));
      expect(targets.length, 1 + circleSteps(spot).length);
      expect(c.step.behavior, Behavior.sleep);
      expect(c.petX, closeTo(spot, 1e-9));
    });

    test('돌기 버릇이 없는 애는 바로 잔다', () async {
      final c = await make(Quirk.sitBeforeEat, affection: 20);
      now = DateTime(2026, 10, 6, 23, 30);
      var walks = 0;
      follow(c, 40, (s) {
        if (s.behavior == Behavior.walk) walks++;
      });
      expect(walks, 0);
      expect(c.step.behavior, Behavior.sleep);
    });

    test('공 놓기 전 한 바퀴 버릇: 물고 와서 공을 문 채 한 바퀴 돌고 내려놓는다', () async {
      final c = await make(Quirk.spinBeforeDrop);
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      var spun = false;
      for (var i = 0; i < 10 && c.step.tag != StepTag.drop; i++) {
        if (c.step.behavior == Behavior.spin) {
          spun = true;
          expect(c.ball, Ball.carried);
        }
        if (c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(0.5);
        }
      }
      expect(spun, isTrue);
      expect(c.step.tag, StepTag.drop);
      expect(c.ball, Ball.ready);
    });

    test('공 버릇이 없는 애는 달려와 바로 내려놓는다', () async {
      final c = await make(Quirk.sitBeforeEat);
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      c.tick(0.5);
      c.arrived();
      expect(c.step.tag, StepTag.drop);
    });

    test('버릇은 처음 한 날엔 일기에 안 나오고, 다른 날 또 하면 한 번만 새어 나온다', () async {
      final c = await make(Quirk.hopWhenPetted);
      c.interact(Interaction.pet);
      await pumpEventQueue(times: 20);
      expect(await events('quirk'), isEmpty);
      // 같은 날 또 해도 아직.
      now = now.add(const Duration(minutes: 5));
      c.interact(Interaction.pet);
      await pumpEventQueue(times: 20);
      expect(await events('quirk'), isEmpty);

      c.sleepApp();
      now = DateTime(2026, 10, 7, 14);
      c.wake();
      c.step = const PetStep(Behavior.idle, 3);
      c.interact(Interaction.pet);
      await pumpEventQueue(times: 20);
      expect(await events('quirk'), [quirkLine(Quirk.hopWhenPetted)]);

      // 그 뒤로는 며칠이 지나도 다시 안 나온다.
      for (final day in [8, 9]) {
        c.sleepApp();
        now = DateTime(2026, 10, day, 14);
        c.wake();
        c.step = const PetStep(Behavior.idle, 3);
        c.interact(Interaction.pet);
        await pumpEventQueue(times: 20);
        expect(await events('quirk'), isEmpty);
      }
    });

    test('밤에 반김 없이 다시 열면 돌기 버릇 펫도 이미 자고 있다(일어나 돌지 않는다)', () async {
      now = DateTime(2026, 10, 6, 22);
      final c = await make(Quirk.circleBeforeSleep);
      c.sleepApp();
      now = DateTime(2026, 10, 6, 23, 30);
      c.wake();
      expect(c.step.behavior, Behavior.sleep);
      var walks = 0;
      follow(c, 40, (s) {
        if (s.behavior == Behavior.walk) walks++;
      });
      expect(walks, 0);
    });

    test('공을 놓기 전 도는 중에 쓰다듬어도 물어 온 보상은 남는다(이미 주인 앞이다)', () async {
      final c = await make(Quirk.spinBeforeDrop);
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      for (var i = 0; i < 10 && c.step.behavior != Behavior.spin; i++) {
        if (c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(0.5);
        }
      }
      expect(c.step.behavior, Behavior.spin);
      final care = c.careScore;
      c.interact(Interaction.pet);
      expect(c.ball, Ball.ready);
      expect(c.careScore, greaterThanOrEqualTo(care + carePlay));
      await pumpEventQueue(times: 20);
      expect(await events('play'), isNotEmpty);
    });

    test('밥 앞에서 앉아 기다릴 땐 담긴 그릇이 보이고 소리도 바로 나며, 그 사이 쓰다듬어도 밥은 먹는다', () async {
      final c = await make(Quirk.sitBeforeEat);
      feed(c);
      expect(c.step.behavior, Behavior.sit);
      expect(c.step.tag, StepTag.bowl);
      expect(c.step.cue, Cue.yip);
      c.interact(Interaction.pet);
      var ate = false;
      for (var i = 0; i < 6 && !ate; i++) {
        c.tick(1);
        ate = c.step.behavior == Behavior.eat;
      }
      expect(ate, isTrue);
    });

    test('반김이 없으면(잠깐 비웠다 열면) 발 냄새도 없다', () async {
      final c = await make(Quirk.sniffOwnerAfterGreet);
      c.sleepApp();
      now = now.add(const Duration(minutes: 10));
      c.wake();
      final steps = <PetStep>[];
      follow(c, 20, steps.add);
      expect(
        steps.any((s) => s.behavior == Behavior.sniff && s.thought == null),
        isFalse,
      );
    });

    test('남은 버릇 이름을 모르면(없어진 버릇) 처음 열 때 지금 버릇으로 다시 남긴다', () async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
      );
      pet = pet.copyWith(lastSeenAt: now, quirk: const Value('없어진 버릇'));
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      expect((await db.loadPet())!.quirk, quirkFor(pet.id, pet.bornAt).name);
    });

    test('한 번뿐인 버릇 줄은 큰 일이 많은 날에도 폰 일기에 들어간다', () {
      DayEvent at(int h, String kind, String detail) =>
          (at: DateTime(2026, 10, 7, h), kind: kind, detail: detail);
      final line = quirkLine(Quirk.sniffOwnerAfterGreet);
      final diary = localDiary([
        at(8, 'greet', '주인이 12시간 만에 돌아와서 꼬리를 흔들며 반겼다'),
        at(8, 'quirk', line),
        at(9, 'walk', '주인이랑 20분 산책했다'),
        at(10, 'find', '같이 산책하다가 도토리를 주워 와서 주인에게 줬다'),
        at(11, 'wish', '공놀이하고 싶었는데 주인이 놀아 줬다'),
        at(12, 'cuddle', '주인 손을 베고 누웠다'),
        at(13, 'friend', '카페에서 코코와 신나게 놀았다'),
      ], Random(1));
      expect(diary, contains(line));
    });

    test('처음 열 때 버릇을 정해 남긴다(같은 펫은 늘 같은 버릇)', () async {
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
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      final want = quirkFor(pet.id, pet.bornAt);
      expect(c.quirk, want);
      expect((await db.loadPet())!.quirk, want.name);
    });
  });
}
