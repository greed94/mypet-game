import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/homecam.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/sleep_spot.dart';

void main() {
  group('규칙', () {
    test('자는 자리: 낯가림은 방석, 친함은 문 앞, 가족은 마지막으로 쓰다듬은 자리', () {
      expect(sleepSpot(Intimacy.stranger), rugX);
      expect(sleepSpot(Intimacy.friend), closeTo(doorX + 0.06, 1e-9));
      expect(sleepSpot(Intimacy.family, lastTouchX: 0.3), 0.3);
      expect(sleepSpot(Intimacy.family), rugX);
      // 방 끝에 붙거나 패드에 걸쳐 자지 않는다.
      expect(sleepSpot(Intimacy.family, lastTouchX: 0.02), 0.15);
      expect(
        sleepSpot(Intimacy.family, lastTouchX: 0.99),
        lessThanOrEqualTo(padX - 0.12),
      );
      expect(firstSpotLine(Intimacy.stranger), isNull);
      for (final i in Intimacy.values) {
        expect(
          (firstSpotLine(i, lastTouchX: 0.3) ?? '').length,
          lessThanOrEqualTo(40),
        );
      }
    });

    test('가족이어도 주인이 만진 적이 없으면 방석에서 자고, "주인 냄새" 일기도 없다', () {
      expect(sleepPlaceName(Intimacy.family), '방석');
      expect(sleepPlaceName(Intimacy.family, lastTouchX: 0.3), '주인 냄새 나는 자리');
      expect(firstSpotLine(Intimacy.family), isNull);
      expect(firstSpotLine(Intimacy.family, lastTouchX: 0.3), isNotNull);
    });

    test('홈캠: 밤잠은 자는 자리에서, 낮잠은 방석에서', () {
      bool nights(DateTime t) => t.hour >= 23 || t.hour < 7;
      final nightNaps = [
        for (var seed = 1; seed <= 10; seed++)
          ...homeCamMoments(
            from: DateTime(2026, 10, 5, 21),
            to: DateTime(2026, 10, 6, 9),
            asleepAt: nights,
            traits: const Traits(activity: 0.8, attachment: 0.2),
            seed: seed,
            sleepX: 0.18,
          ).where((m) => m.kind == CamKind.nap),
      ];
      expect(nightNaps, isNotEmpty);
      expect(nightNaps.map((m) => m.x), everyElement(0.18));
      final dayNaps = [
        for (var seed = 1; seed <= 10; seed++)
          ...homeCamMoments(
            from: DateTime(2026, 10, 6, 9),
            to: DateTime(2026, 10, 6, 17),
            asleepAt: nights,
            traits: const Traits(activity: 0.3, attachment: 0.2),
            seed: seed,
            sleepX: 0.18,
          ).where((m) => m.kind == CamKind.nap),
      ];
      expect(dayNaps, isNotEmpty);
      expect(dayNaps.map((m) => m.x), everyElement(rugX));
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

    Future<PetController> make({
      double affection = 50,
      String? marks,
      Duration away = Duration.zero,
    }) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
      );
      pet = pet.copyWith(
        lastSeenAt: now.subtract(away),
        affection: affection,
        pawMarks: Value(marks),
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

    /// 앱을 켜 둔 채 밤이 됐다. 하던 동작을 마치고 다음 동작을 고를 때까지.
    void nightFalls(PetController c) {
      now = DateTime(2026, 10, 6, 23, 30);
      final before = c.step;
      for (var i = 0; i < 20 && identical(c.step, before); i++) {
        c.tick(1);
      }
    }

    test('친해진 펫은 밤이 되면 문 앞으로 걸어가 자고, 처음 그 자리에서 잔 날 일기에 한 번 남긴다', () async {
      final c = await make(affection: 50);
      expect(c.intimacy, Intimacy.friend);
      c.petX = 0.6;
      nightFalls(c);
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, closeTo(doorX + 0.06, 1e-9));
      c.arrived();
      expect(c.petX, closeTo(doorX + 0.06, 1e-9));
      expect(c.step.behavior, Behavior.sleep);
      // 자리에 닿았으니 다시 걷지 않고 계속 잔다.
      for (var i = 0; i < 100; i++) {
        c.tick(1);
        expect(c.step.behavior, Behavior.sleep);
      }
      await pumpEventQueue(times: 20);
      expect(await events('spot'), [firstSpotLine(Intimacy.friend)]);
    });

    test('낯가리는 펫은 방석에서 잔다. 처음부터 자던 곳이라 일기는 없다', () async {
      final c = await make(affection: 20);
      c.petX = 0.8;
      nightFalls(c);
      expect(c.step.targetX, rugX);
      c.arrived();
      for (var i = 0; i < 40; i++) {
        c.tick(1);
      }
      expect(c.step.behavior, Behavior.sleep);
      await pumpEventQueue(times: 20);
      expect(await events('spot'), isEmpty);
    });

    test('가족은 주인이 마지막으로 쓰다듬은 자리에서 잔다. 그 자리는 앱을 다시 열어도 남는다', () async {
      final c = await make(affection: 80, marks: 'hidden');
      c.petX = 0.3;
      c.interact(Interaction.pet);
      await pumpEventQueue(times: 20);
      expect((await db.loadPet())!.touchX, closeTo(0.3, 1e-9));
      c.petX = 0.7;
      nightFalls(c);
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, closeTo(0.3, 1e-9));
      c.arrived();
      for (var i = 0; i < 31; i++) {
        c.tick(1);
      }
      await pumpEventQueue(times: 20);
      expect(await events('spot'), [
        firstSpotLine(Intimacy.family, lastTouchX: 0.3),
      ]);
    });

    test('가족이어도 주인이 만진 적이 없으면 방석에서 자고 "주인 냄새" 일기는 없다', () async {
      final c = await make(affection: 80, marks: 'hidden');
      nightFalls(c);
      expect(c.step.behavior, Behavior.sleep);
      for (var i = 0; i < 31; i++) {
        c.tick(1);
      }
      await pumpEventQueue(times: 20);
      expect(await events('spot'), isEmpty);
    });

    test('자는 사이에 앱을 열면 펫은 이미 제 자리에서 자고 있다(걸어가는 걸 보여 주지 않는다)', () async {
      final c = await make(affection: 50);
      c.petX = 0.7;
      c.sleepApp();
      final gen = c.snapGen;
      now = DateTime(2026, 10, 7, 1);
      c.wake();
      expect(c.snapGen, gen + 1);
      expect(c.petX, closeTo(doorX + 0.06, 1e-9));
      expect(c.step.behavior, isNot(Behavior.walk));
      // 잠깐 껐다 켠 건 옮기지 않는다.
      c.sleepApp();
      now = now.add(const Duration(minutes: 2));
      c.wake();
      expect(c.snapGen, gen + 1);
    });

    test('앱이 새로 뜬 밤에는 잠깐 비웠어도 자는 자리에서 시작한다(어디 있었는지 모르니)', () async {
      now = DateTime(2026, 10, 6, 23, 30);
      final c = await make(affection: 50);
      expect(c.snapGen, 1);
      expect(c.petX, closeTo(doorX + 0.06, 1e-9));
    });

    test('다시보기 중에 껐다가 밤에 잠깐 뒤 다시 열면 다시보기 마무리 없이 자는 자리에 있다', () async {
      now = DateTime(2026, 10, 6, 22, 50);
      final c = await make(affection: 50, away: const Duration(hours: 3));
      expect(c.homeCam, isNotEmpty);
      c.startReplay();
      expect(c.replaying, isTrue);
      c.sleepApp();
      now = DateTime(2026, 10, 6, 23, 5);
      c.wake();
      expect(c.replaying, isFalse);
      expect(c.step.tag, isNot(StepTag.cut));
      expect(c.petX, closeTo(doorX + 0.06, 1e-9));
    });

    test('손 베개로 내민 자리도 주인이 만진 자리로 남는다', () async {
      final c = await make(affection: 80, marks: 'hidden');
      c.offerHand(0.3);
      for (var i = 0; i < 30 && c.step.tag != StepTag.hand; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
      expect(c.step.tag, StepTag.hand);
      await pumpEventQueue(times: 20);
      expect((await db.loadPet())!.touchX, closeTo(0.3, 1e-9));
    });

    test('밤에 주인이 손을 대고 있으면 문 앞으로 가지 않고 손 곁에서 잔다. 손을 거두면 그때 간다', () async {
      final c = await make(affection: 50);
      now = DateTime(2026, 10, 6, 23, 30);
      c.offerHand(0.5);
      bool toDoor(PetController c) =>
          c.step.behavior == Behavior.walk &&
          (c.step.targetX! - (doorX + 0.06)).abs() < 1e-9;
      var left = false;
      for (var i = 0; i < 60; i++) {
        left |= toDoor(c);
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
      expect(left, isFalse);
      expect(c.handX, isNotNull);
      expect(c.step.behavior, Behavior.sleep);
      c.releaseHand();
      expect(c.handX, isNull);
      for (var i = 0; i < 40 && !toDoor(c); i++) {
        c.tick(1);
      }
      expect(toDoor(c), isTrue);
    });

    test('밤에 카페에서 돌아오면 가운데를 거치지 않고 자는 자리로 간다', () async {
      now = DateTime(2026, 10, 6, 22);
      final c = await make(affection: 50);
      expect(c.goToCafe(), isTrue);
      now = DateTime(2026, 10, 6, 23, 30);
      c.comeHome();
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, closeTo(doorX + 0.06, 1e-9));
    });
  });
}
