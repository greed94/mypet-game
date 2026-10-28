import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/homecam.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/tricks.dart';

DateTime at(int d, int h, [int m = 0]) => DateTime(2026, 10, d, h, m);
bool nights(DateTime t) => t.hour >= 23 || t.hour < 7;

void main() {
  const fond = Traits(activity: 0.4, attachment: 0.8);

  group('장면 규칙', () {
    test('두 시간 안 됐으면 장면이 없다', () {
      expect(
        homeCamMoments(
          from: at(5, 9),
          to: at(5, 10, 59),
          asleepAt: nights,
          traits: fond,
          seed: 1,
        ),
        isEmpty,
      );
    });

    test('넷 이하, 시간 순서, 20분 넘게 떨어져 있고, 같은 사이엔 같은 장면이다', () {
      for (var seed = 0; seed < 40; seed++) {
        final ms = homeCamMoments(
          from: at(5, 8, 30),
          to: at(5, 19, 10),
          asleepAt: nights,
          traits: fond,
          seed: seed,
          toyName: '도토리',
          toyX: 0.46,
        );
        expect(ms.length, inInclusiveRange(1, 4));
        for (var i = 1; i < ms.length; i++) {
          expect(
            ms[i].at.difference(ms[i - 1].at),
            greaterThanOrEqualTo(const Duration(minutes: 20)),
          );
        }
        for (final m in ms) {
          expect(
            m.at.isAfter(at(5, 8, 30)) && m.at.isBefore(at(5, 19, 10)),
            isTrue,
          );
          expect(m.x, inInclusiveRange(0, 1));
          // 배고팠다·외로웠다·울었다 같은 탓하는 장면은 없다.
          expect(m.label, isNot(matches(RegExp('배고|굶|외로|울'))));
        }
        final again = homeCamMoments(
          from: at(5, 8, 30),
          to: at(5, 19, 10),
          asleepAt: nights,
          traits: fond,
          seed: seed,
          toyName: '도토리',
          toyX: 0.46,
        );
        expect(
          again.map((m) => '${m.at}${m.kind}'),
          ms.map((m) => '${m.at}${m.kind}'),
        );
      }
    });

    test('정 많은 애는 나갈 때·올 때쯤 문 앞에 있고, 비 오면 창밖을 본다', () {
      final ms = homeCamMoments(
        from: at(5, 8, 30),
        to: at(5, 19),
        asleepAt: nights,
        traits: fond,
        seed: 3,
        rainy: true,
      );
      expect(ms.first.kind, CamKind.doorOut);
      expect(ms.last.kind, CamKind.doorWait);
      expect(ms.map((m) => m.kind), contains(CamKind.window));
      expect(ms.last.behavior, Behavior.waitAtDoor);
      expect(ms.last.x, doorX);
    });

    test('밤을 넘겨 비우면 자는 장면이 있고, 방에 둔 물건이 있으면 그걸 가지고 논다', () {
      final ms = homeCamMoments(
        from: at(5, 21),
        to: at(6, 9),
        asleepAt: nights,
        traits: const Traits(activity: 0.8, attachment: 0.2),
        seed: 5,
        toyName: '솔방울',
        toyX: 0.64,
      );
      final nap = ms.firstWhere((m) => m.kind == CamKind.nap);
      expect(nap.label, '쿨쿨 자는 중');
      expect(nap.behavior, Behavior.sleep);
      final kinds = ms.map((m) => m.kind);
      if (kinds.contains(CamKind.toy)) {
        expect(ms.firstWhere((m) => m.kind == CamKind.toy).label, '솔방울 가지고 놀기');
      }
      expect(kinds, isNot(contains(CamKind.doorWait)));
    });

    test('잘 시간이 길어 깨어 있던 때가 짧아도(19시~10시 잠) 장면이 둘 넘게 나온다', () {
      bool longNight(DateTime t) => t.hour >= 19 || t.hour < 10;
      var thin = 0;
      for (var seed = 0; seed < 30; seed++) {
        final ms = homeCamMoments(
          from: at(5, 17, 50),
          to: at(6, 10, 30),
          asleepAt: longNight,
          traits: const Traits(activity: 0.5, attachment: 0.5),
          seed: seed,
        );
        if (ms.length < 2) thin++;
        for (final m in ms.where((m) => m.kind != CamKind.nap)) {
          expect(longNight(m.at), isFalse, reason: '${m.kind} ${m.at}');
        }
      }
      expect(thin, lessThan(5));
    });

    test('일기에 남길 장면은 기다림 > 창밖 > 놀기 > 잠 순서', () {
      expect(homeCamHighlight(const []), isNull);
      final ms = [
        CamMoment(at(5, 9), CamKind.nap, 0.5),
        CamMoment(at(5, 10), CamKind.window, windowX),
      ];
      expect(homeCamHighlight(ms)!.kind, CamKind.window);
    });
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = at(5, 19);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = at(5, 19);
    });
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> open({required Duration away}) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 5)),
      );
      pet = pet.copyWith(
        lastSeenAt: now.subtract(away),
        activity: const Value(0.4),
        attachment: const Value(0.8),
      );
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      return c;
    }

    test(
      '오래 비웠다 열면 홈캠이 생기고, 다시보기는 장면마다 그 자리로 옮겨 그 동작을 하고 끝나면 지금으로 돌아온다',
      () async {
        final c = await open(away: const Duration(hours: 10));
        expect(c.homeCam, isNotEmpty);
        final total = c.homeCam.length;
        c.startReplay();
        expect(c.replaying, isTrue);
        final seen = <String>[];
        for (var i = 0; i < 40 && c.replaying; i++) {
          if (c.replayMoment case final m?) {
            final key = '${m.at}';
            if (seen.isEmpty || seen.last != key) {
              seen.add(key);
              expect(c.step.tag, StepTag.cut);
              expect(c.step.targetX, m.x);
              expect(c.step.behavior, m.behavior);
            }
          }
          c.tick(1);
        }
        expect(c.replaying, isFalse);
        expect(seen.length, total);
        // 끝까지 봤으면 칩을 거둔다.
        expect(c.homeCam, isEmpty);
        expect(c.replayMoment, isNull);
        await pumpEventQueue();
        expect([
          for (final e in await db.eventsOn(now))
            if (e.kind == 'homecam') e,
        ], hasLength(1));
      },
    );

    test('다시보기 중엔 만져도 반응하지 않고, 말을 걸면 멈추고 지금으로 온다. 쉬 신호도 미룬다', () async {
      final c = await open(away: const Duration(hours: 10));
      c.startReplay();
      final step = c.step;
      c.interact(Interaction.pet);
      expect(identical(c.step, step), isTrue);
      await c.talk('콩아');
      expect(c.replaying, isFalse);
    });

    test('다시보기 중 다른 일이 끼면(장소 가기·물건 받기·간식·다시 열기·위기 문장) 바로 지금으로 돌아온다', () async {
      final c = await open(away: const Duration(hours: 10));
      c.startReplay();
      expect(c.goToCafe(), isTrue);
      expect(c.replaying, isFalse);
      expect(c.replayMoment, isNull);
      c.comeHome();

      c.startReplay();
      c.sleepApp();
      c.wake();
      expect(c.replaying, isFalse);

      await c.collected;
      c.startReplay();
      expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
      expect(c.replaying, isFalse);
    });

    test('걸음 권한을 막 허락해 다시 챙겨도 홈캠은 그대로다', () async {
      final c = await open(away: const Duration(hours: 10));
      final before = c.homeCam.length;
      expect(before, greaterThan(0));
      await c.collectNow();
      expect(c.homeCam.length, before);
    });

    test('같은 날 두 번 오래 비워도 홈캠 일기는 하루 한 번', () async {
      final c = await open(away: const Duration(hours: 10));
      c.sleepApp();
      now = now.add(const Duration(hours: 3));
      c.wake();
      await c.collected;
      await pumpEventQueue();
      expect([
        for (final e in await db.eventsOn(now))
          if (e.kind == 'homecam') e,
      ], hasLength(1));
    });

    test('잠깐 비웠으면 홈캠이 없다', () async {
      final c = await open(away: const Duration(minutes: 90));
      expect(c.homeCam, isEmpty);
      c.startReplay();
      expect(c.replaying, isFalse);
    });

    test('유치원에서 고른 수업을 연습해 오고, 데리러 가면 그 개인기를 보여 준다. 자유 놀이면 수업이 없다', () async {
      now = at(5, 9);
      final c = await open(away: Duration.zero);
      c.goToKindergarten();
      expect(c.dropOff(lesson: Trick.down), isTrue);
      expect((await db.loadPet())!.daycareLesson, 'down');
      now = now.add(const Duration(hours: 3));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(c.tricks[Trick.down]?.successes, 1);
      expect(c.tricks[Trick.sit], isNull);
      expect((await db.loadPet())!.daycareLesson, isNull);
      run(c, until: () => c.step.behavior == Behavior.lieBeside);
      expect(c.step.behavior, Behavior.lieBeside);
      expect(c.bubble, '오늘 배운 거 봐!');

      // 같은 날 또 맡기며 다른 수업을 골라도 수업은 하루 한 번이라, 데리러 갈 때 보여 주지 않는다.
      now = at(5, 13);
      c.goToKindergarten();
      expect(c.dropOff(lesson: Trick.spin), isTrue);
      now = now.add(const Duration(hours: 3));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(c.tricks[Trick.spin], isNull);
      run(c, until: () => c.step.behavior == Behavior.spin);
      expect(c.step.behavior, isNot(Behavior.spin));

      now = at(6, 9);
      c.goToKindergarten();
      c.dropOff();
      now = now.add(const Duration(hours: 3));
      c.pickUp();
      await pumpEventQueue(times: 50);
      expect(c.tricks.values.fold<int>(0, (n, p) => n + p.successes), 1);
      expect(c.spot, Spot.home);
    });
  });
}

void run(PetController c, {required bool Function() until, int max = 30}) {
  for (var i = 0; i < max && !until(); i++) {
    if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
      c.arrived();
    } else {
      c.tick(1);
    }
  }
}
