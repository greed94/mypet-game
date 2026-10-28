import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/sprite_art.dart';
import 'package:mypet/pet/kinder_photo.dart';
import 'package:mypet/pet/kindergarten.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

/// 유치원 오늘의 한 장(아이디어 C2): 하원 때 그날 친구들과의 장면 하나가 일기에 붙는다.
void main() {
  group('규칙', () {
    DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

    test('점심·낮잠은 그 시간에 있었을 때만, 수업은 수업한 날만', () {
      expect(kinderScenes(at(9), at(11, 30), lesson: false), [
        KinderScene.play,
        KinderScene.run,
      ]);
      expect(
        kinderScenes(at(9), at(12, 30), lesson: false),
        contains(KinderScene.lunch),
      );
      expect(
        kinderScenes(at(9), at(12, 30), lesson: false),
        isNot(contains(KinderScene.nap)),
      );
      expect(kinderScenes(at(13, 30), at(15), lesson: true), [
        KinderScene.play,
        KinderScene.run,
        KinderScene.nap,
        KinderScene.lesson,
      ]);
      expect(
        kinderScenes(at(14), at(19), lesson: false),
        isNot(contains(KinderScene.nap)),
      );
    });

    test('한 시간은 있어야 한 장이 남고, 친구는 그날 온 애들 중 둘이다', () {
      expect(
        planKinderPhoto(at(9), at(9, 50), lesson: false, random: Random(1)),
        isNull,
      );
      final today = [for (final g in friendsOn(at(9))) g.id];
      for (var seed = 0; seed < 30; seed++) {
        final p = planKinderPhoto(
          at(9),
          at(19),
          lesson: true,
          random: Random(seed),
        )!;
        expect(p.friends, hasLength(2));
        expect(p.friends.toSet(), hasLength(2));
        expect(today, containsAll(p.friends));
      }
    });

    test('그날만 있는 장면이 두 배 잘 뽑힌다', () {
      var lessons = 0;
      for (var seed = 0; seed < 400; seed++) {
        final p = planKinderPhoto(
          at(9),
          at(11),
          lesson: true,
          random: Random(seed),
        )!;
        if (p.scene == KinderScene.lesson) lessons++;
      }
      // 놀이 1, 술래잡기 1, 수업 2 → 수업이 절반쯤.
      expect(lessons, inInclusiveRange(150, 250));
    });

    test('점심 장면은 정오를 거쳐 있었을 때만(유치원 점심 계산과 같게)', () {
      expect(
        kinderScenes(at(12, 5), at(14), lesson: false),
        isNot(contains(KinderScene.lunch)),
      );
      expect(
        kinderScenes(at(11, 50), at(12, 30), lesson: false),
        contains(KinderScene.lunch),
      );
      expect(
        kinderScenes(at(12), at(13), lesson: false),
        contains(KinderScene.lunch),
      );
    });

    test('입 위치는 (줄, 칸)으로 찾고, 없으면 그 줄 첫 칸, 그것도 없으면 기본값', () {
      final m = {(3, 2): (23, 20), (3, 0): (26, 20)};
      expect(mouthAt(m, 3, 2), (23, 20));
      expect(mouthAt(m, 3, 1), (26, 20));
      expect(mouthAt(m, 5, 0), (28, 13));
    });

    test('사진 밑 글', () {
      expect(kinderCaption(KinderScene.nap, null), '낮잠 시간');
      expect(kinderCaption(KinderScene.lesson, Trick.sit), "'앉아' 수업");
      expect(kinderCaption(KinderScene.lesson, null), '수업 시간');
    });
  });

  group('컨트롤러', () {
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
        stage: PetStage.puppy,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 2)),
      );
      pet = pet.copyWith(lastSeenAt: now, affection: 40);
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      return c;
    }

    test('데리러 가면 그날 한 장이 남는다(그날 친구 둘, 그날 성장 단계)', () async {
      final c = await make();
      c.goToKindergarten();
      c.dropOff(lesson: Trick.sit);
      now = now.add(const Duration(hours: 6));
      c.pickUp();
      await pumpEventQueue(times: 50);
      final p = (await db.kinderPhotoOn('2026-10-05'))!;
      expect(p.stage, PetStage.puppy);
      expect([
        for (final g in friendsOn(DateTime(2026, 10, 5, 9))) g.id,
      ], containsAll(p.friends.split(',')));
      expect(
        kinderScenes(
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 15),
          lesson: true,
        ).map((s) => s.name),
        contains(p.scene),
      );
      expect(p.trick, p.scene == 'lesson' ? 'sit' : isNull);
    });

    test('버스로 온 날은 다음 날 열어도 맡긴 날 한 장으로 남는다', () async {
      final c = await make();
      c.goToKindergarten();
      c.dropOff();
      c.sleepApp();
      await pumpEventQueue();
      now = now.add(const Duration(hours: 23));
      final later = PetController(
        db,
        (await db.loadPet())!,
        random: Random(2),
        clock: () => now,
      );
      later.wake();
      await later.collected;
      await pumpEventQueue(times: 50);
      final photos = await db.allKinderPhotos();
      expect(photos.single.day, '2026-10-05');
      expect(photos.single.trick, isNull);
    });

    test('잠깐 맡기면 사진이 없고, 같은 날 또 맡겨도 처음 한 장만 남는다', () async {
      final c = await make();
      c.goToKindergarten();
      c.dropOff();
      now = now.add(const Duration(minutes: 40));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(await db.allKinderPhotos(), isEmpty);

      c.goToKindergarten();
      c.dropOff();
      now = now.add(const Duration(hours: 2));
      c.pickUp();
      await pumpEventQueue(times: 50);
      final first = (await db.allKinderPhotos()).single;

      c.goToKindergarten();
      c.dropOff();
      now = now.add(const Duration(hours: 3));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect((await db.allKinderPhotos()).single, first);
    });

    test('며칠 만에 열어도 맡긴 날 일기가 폰 일기로 생겨 사진이 붙고, AI는 어제 일기만 쓴다', () async {
      final c = await make();
      c.goToKindergarten();
      c.dropOff();
      c.sleepApp();
      await pumpEventQueue();
      // 월요일에 맡기고 수요일 아침에 처음 연다. 버스 하원은 그때 월요일 저녁 시각으로 남는다.
      now = DateTime(2026, 10, 7, 8);
      final brain = _CountingBrain();
      final later = PetController(
        db,
        (await db.loadPet())!,
        random: Random(2),
        clock: () => now,
        brain: brain,
      );
      later.wake();
      await later.collected;
      await pumpEventQueue(times: 100);
      final monday = (await db.allDiaries()).singleWhere(
        (d) => d.day == '2026-10-05',
      );
      expect(monday.content, contains('버스'));
      expect(monday.byAi, isFalse);
      expect(await db.kinderPhotoOn('2026-10-05'), isNotNull);
      // 화요일(어제)엔 일이 없어 일기도 없고 AI도 부르지 않는다.
      expect(brain.diaries, 0);
      expect(
        (await db.allDiaries()).map((d) => d.day),
        isNot(contains('2026-10-06')),
      );
    });

    test('처음부터 다시 하면 사진도 지운다', () async {
      final c = await make();
      c.goToKindergarten();
      c.dropOff();
      now = now.add(const Duration(hours: 3));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(await db.allKinderPhotos(), hasLength(1));
      await db.resetAll();
      expect(await db.allKinderPhotos(), isEmpty);
    });
  });
}

/// 일기를 몇 번 쓰라고 했는지 센다.
class _CountingBrain implements PetBrain {
  int diaries = 0;

  @override
  String get label => '세는 뇌';

  // 반김 속마음은 정상으로 돌려준다. 실패하면 AI를 잠시 끈 것으로 쳐서 일기도 폰이 써 버린다.
  @override
  Future<PetDecision> decide(String system, String user) async =>
      const PetDecision(
        moodDelta: 0,
        affectionDelta: 0,
        action: PetAction.happy,
        thought: '왔다!',
      );

  @override
  Future<String> writeText(String system, String user) async {
    diaries++;
    return '오늘은 좋은 날이었다.';
  }
}
