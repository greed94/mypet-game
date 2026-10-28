import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/shapes.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';

Guest _dog(String id, {String shape = 'shiba'}) => knownGuest(
  id: id,
  shape: shape,
  main: 0xFFC48C54,
  second: 0xFFF4E2C4,
  marking: 0xFF8A5E3B,
);

void main() {
  group('규칙', () {
    test('아는 강아지가 없으면 단골 뽑기가 전과 똑같다', () {
      for (var h = 0; h < 24 * 14; h += 6) {
        final t = DateTime(2026, 10, 1).add(Duration(hours: h));
        expect(
          guestsAt(t, known: const []).map((g) => g.id),
          guestsAt(t).map((g) => g.id),
        );
      }
    });

    test('아직 못 만난 아는 강아지는 꼭 오고, 단골 순서는 그대로 이어진다', () {
      final toto = _dog('known_1_0');
      for (var h = 0; h < 24 * 14; h += 6) {
        final t = DateTime(2026, 10, 1).add(Duration(hours: h));
        final plain = guestsAt(t).map((g) => g.id).toList();
        final withToto = guestsAt(
          t,
          known: [toto],
          newcomers: {toto.id},
        ).map((g) => g.id).toList();
        expect(withToto.first, toto.id);
        expect(withToto.length, plain.length);
        expect(withToto.skip(1), plain.take(plain.length - 1));
      }
    });

    test('만난 뒤엔 시간대마다 반쯤 오고, 같은 시간대엔 늘 같다', () {
      final toto = _dog('known_1_0');
      var came = 0;
      const slots = 400;
      for (var i = 0; i < slots; i++) {
        final t = DateTime(2026, 10, 1).add(Duration(hours: i * 6));
        final ids = guestsAt(t, known: [toto]).map((g) => g.id);
        if (ids.contains(toto.id)) came++;
        expect(
          guestsAt(
            t.add(const Duration(hours: 1)),
            known: [toto],
          ).map((g) => g.id),
          ids,
        );
      }
      expect(came / slots, inInclusiveRange(0.4, 0.6));
    });

    test('아는 강아지가 많아도 두 자리까지만 앉고, 손님은 둘이나 셋이다', () {
      final known = [for (var i = 0; i < maxKnownDogs; i++) _dog('known_9_$i')];
      for (var h = 0; h < 24 * 7; h += 6) {
        final t = DateTime(2026, 10, 1).add(Duration(hours: h));
        final got = guestsAt(
          t,
          known: known,
          newcomers: {for (final g in known) g.id},
        );
        expect(got.length, inInclusiveRange(2, 3));
        expect(
          got.where((g) => g.id.startsWith('known_')).length,
          lessThanOrEqualTo(2),
        );
        expect(got.map((g) => g.id).toSet().length, got.length);
      }
    });

    test('생김새로 부르는 말이 있고, 목걸이 색은 털색으로 정해진다', () {
      for (final s in friendShapes) {
        expect(_dog('a', shape: s.id).look, isNotEmpty);
      }
      expect(_dog('a').accent, _dog('b').accent);
      expect(friendShapes.map((s) => s.id), isNot(contains('noeul')));
      // 값을 박아 둔다. 해시 함수가 바뀌면 이미 데려온 애들의 좋아하는 것·오는 때가 통째로 바뀐다.
      expect(stableHash('known_1_0'), 477764774);
      expect(
        {for (var i = 0; i < 20; i++) _dog('known_0_$i').taste}.length,
        greaterThan(1),
      );
    });

    test('시간대는 펫의 하루(새벽 5시 시작) 기준이라 밤 11시와 새벽 4시 59분은 같은 얼굴이다', () {
      final ids = guestsAt(DateTime(2026, 10, 5, 23)).map((g) => g.id);
      expect(guestsAt(DateTime(2026, 10, 6, 0, 30)).map((g) => g.id), ids);
      expect(guestsAt(DateTime(2026, 10, 6, 4, 59)).map((g) => g.id), ids);
    });

    test('처음 만난 날(펫의 하루)엔 하루 내내 꼭 오고, 다음 날부터는 반쯤', () {
      const fresh = Friendship(name: '토토');
      expect(newcomerAt(null, DateTime(2026, 10, 5, 14)), isTrue);
      expect(newcomerAt(fresh, DateTime(2026, 10, 5, 14)), isTrue);
      // 새벽 4시 30분에 처음 만났으면 그 펫의 하루는 10월 4일이다.
      final met = fresh.met(dayKey(petDate(DateTime(2026, 10, 5, 4, 30))));
      expect(newcomerAt(met, DateTime(2026, 10, 5, 4, 50)), isTrue);
      expect(newcomerAt(met, DateTime(2026, 10, 5, 5, 10)), isFalse);
      final twice = met.met('2026-10-05');
      expect(newcomerAt(twice, DateTime(2026, 10, 5, 14)), isFalse);
    });
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = DateTime(2026, 10, 2, 14);
    const brown = PetColors(
      main: 0xFFC48C54,
      second: 0xFFF4E2C4,
      marking: 0xFF8A5E3B,
    );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 2, 14);
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
        now: now.subtract(const Duration(days: 3)),
      );
      pet = pet.copyWith(lastSeenAt: now);
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: () => now);
      c.wake();
      await c.collected;
      return c;
    }

    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    /// 입장 걷기부터 만남 장면 끝(StepTag.meet)까지 흘려 보내며 속마음을 모은다.
    Set<String> playMeeting(PetController c) {
      final thoughts = <String>{};
      for (var i = 0; i < 60 && c.step.tag != StepTag.meet; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
        if (c.step.thought case final t?) thoughts.add(t);
      }
      return thoughts;
    }

    test('데려온 강아지는 다음 카페에 꼭 와 있고, 더 친한 단골이 있어도 그 애와 처음 만나는 장면을 본다', () async {
      final c = await make();
      // 단골 하나는 이미 킁킁 사이라 오늘 놀이로 오른다(원래라면 이 애가 장면 주인공).
      final regular = guestsAt(now).first;
      c.friends[regular.id] = const Friendship(
        bond: Bond.sniff,
        days: 2,
        lastDay: 'x',
      );
      final toto = await c.addKnownDog(
        name: ' 토토 ',
        shape: 'corgi',
        colors: brown,
      );
      expect(toto, isNotNull);
      expect(c.knownDogs.single.id, toto!.id);
      expect(toto.id, isNot(contains('토토')));
      expect(c.friends[toto.id]?.name, '토토');

      expect(c.goToCafe(), isTrue);
      expect(c.guests.map((g) => g.id), contains(toto.id));
      expect(c.guests.map((g) => g.id), contains(regular.id));
      await pumpEventQueue(times: 50);
      expect(c.friends[toto.id]?.bond, Bond.stranger);
      expect(c.friends[regular.id]?.bond, Bond.play);
      // 카드 글: 데려온 애가 맨 앞, 이름 있는 애는 수로 묶지 않는다.
      expect(c.cafeNote, startsWith('토토 낯섦'));
      expect(playMeeting(c), contains('…누구지?'));
      expect(await events('friend'), anyElement(contains('토토를 처음 봤다')));
    });

    test('만난 다음 날부터는 시간대마다 반쯤 오고, 어제 만났으면 창밖으로 지나가고 꿈에도 나온다', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'pug',
        colors: brown,
      ))!;
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.metToday.map((g) => g.id), contains(toto.id));
      c.comeHome();

      now = now.add(const Duration(days: 1));
      // 어제 만난 애가 토토뿐이면 창밖으로 지나가는 애는 토토다.
      c.friends.removeWhere((id, f) => id != toto.id);
      while (windowPass(now, c.pet.id) == null) {
        now = now.add(const Duration(seconds: 1));
      }
      c.step = const PetStep(Behavior.idle, 5);
      c.tick(0.1);
      expect(c.windowPasser?.id, toto.id);
    });

    test('모습·이름을 고치면 카페에 앉아 있는 그 애도 바뀌고, 다시 열어도 남는다', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      c.goToCafe();
      await pumpEventQueue(times: 50);
      const white = PetColors(
        main: 0xFFF8F1E6,
        second: 0xFFFFFDF8,
        marking: 0xFF914F28,
      );
      await c.editKnownDog(
        toto.id,
        name: '하양이',
        shape: 'maltese',
        colors: white,
        puppy: true,
      );
      final seated = c.guests.firstWhere((g) => g.id == toto.id);
      expect(seated.shape, 'maltese');
      expect(seated.main, white.main);
      expect(seated.puppy, isTrue);
      expect(c.friends[toto.id]?.name, '하양이');
      // 고쳐도 사이는 그대로다.
      expect(c.friends[toto.id]?.bond, Bond.stranger);

      final again = PetController(
        db,
        c.pet,
        random: Random(2),
        clock: () => now,
      );
      again.wake();
      await again.collected;
      expect(again.knownDogs.single.shape, 'maltese');
      expect(again.knownDogs.single.puppy, isTrue);
      expect(again.friends[toto.id]?.name, '하양이');
    });

    test('지우면 카페 자리·사이·이름이 다 빠진다', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final before = c.guests.length;
      await c.removeKnownDog(toto.id);
      expect(c.knownDogs, isEmpty);
      expect(c.guests.length, before - 1);
      expect(c.friends.containsKey(toto.id), isFalse);
      expect(await db.loadKnownDogs(), isEmpty);
      expect((await db.loadFriends()).containsKey(toto.id), isFalse);
    });

    test('이름이 비었거나 다 찼으면 데려오지 않는다', () async {
      final c = await make();
      expect(
        await c.addKnownDog(name: '   ', shape: 'shiba', colors: brown),
        isNull,
      );
      for (var i = 0; i < maxKnownDogs; i++) {
        expect(
          await c.addKnownDog(name: '친구$i', shape: 'shiba', colors: brown),
          isNotNull,
        );
      }
      expect(
        await c.addKnownDog(name: '하나 더', shape: 'shiba', colors: brown),
        isNull,
      );
      // 같은 시각에 여럿 데려와도 id가 겹치지 않는다.
      expect(c.knownDogs.map((g) => g.id).toSet().length, maxKnownDogs);
      // 다시 열어도 데려온 순서 그대로다(같은 시각이면 id 순).
      final again = PetController(
        db,
        c.pet,
        random: Random(2),
        clock: () => now,
      );
      again.wake();
      await again.collected;
      expect(again.knownDogs.map((g) => g.id), c.knownDogs.map((g) => g.id));
    });

    test('처음 만난 뒤 같은 시간대에 다시 가도 손님 얼굴이 그대로다', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      // 만난 뒤라면 반쯤의 확률에서 빠졌을 시간대를 고른다(그래야 이 테스트가 의미가 있다).
      for (var i = 0; i < 200; i++) {
        if (!guestsAt(now, known: [toto]).any((g) => g.id == toto.id)) break;
        now = now.add(const Duration(hours: 6));
      }
      expect(guestsAt(now, known: [toto]).any((g) => g.id == toto.id), isFalse);
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final first = c.guests.map((g) => g.id).toList();
      expect(first, contains(toto.id));
      expect(c.friends[toto.id]?.bond, Bond.stranger);
      c.comeHome();
      now = now.add(const Duration(minutes: 10));
      c.goToCafe();
      expect(c.guests.map((g) => g.id), first);
    });

    test('아는 강아지 카드에서 이름을 비우고 저장해도 이름이 남는다(단골은 뗄 수 있다)', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      await c.nameFriend(toto.id, '   ');
      expect(c.friends[toto.id]?.name, '토토');
      expect((await db.loadFriends())[toto.id]?.name, '토토');
      final regular = cafeRegulars.first;
      await c.nameFriend(regular.id, '코코');
      await c.nameFriend(regular.id, '');
      expect(c.friends[regular.id]?.name, isNull);
    });

    test('만남 처리 중에 아는 강아지를 지우면 그 애의 사이가 되살아나지 않는다', () async {
      final c = await make();
      final a = (await c.addKnownDog(
        name: '하나',
        shape: 'corgi',
        colors: brown,
      ))!;
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      c.goToCafe();
      expect(c.guests.map((g) => g.id), containsAll([a.id, toto.id]));
      // 첫 애(하나)를 저장하는 사이에 둘째(토토)를 지운다.
      await c.removeKnownDog(toto.id);
      await pumpEventQueue(times: 50);
      expect(c.friends.containsKey(toto.id), isFalse);
      expect((await db.loadFriends()).containsKey(toto.id), isFalse);
      expect(c.cafeNote, isNot(contains('토토')));
      expect(c.friends[a.id]?.bond, Bond.stranger);
    });

    test('만남 처리 중에 모습을 고쳐도 카페 카드 글에 그 애가 한 번만 나온다', () async {
      final c = await make();
      final toto = (await c.addKnownDog(
        name: '토토',
        shape: 'shiba',
        colors: brown,
      ))!;
      c.goToCafe();
      unawaited(
        c.editKnownDog(
          toto.id,
          name: '하양이',
          shape: 'maltese',
          colors: const PetColors(
            main: 0xFFF8F1E6,
            second: 0xFFFFFDF8,
            marking: 0xFF914F28,
          ),
        ),
      );
      await pumpEventQueue(times: 50);
      expect('하양이'.allMatches(c.cafeNote).length, 1);
      expect(c.cafeNote, startsWith('하양이 낯섦'));
    });
  });

  test('처음부터 다시 하면 모든 표가 빈다(아는 강아지와 그 이름까지)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 10, 4);
    await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    await db.addMemory('기억', now);
    await db.addEvent('walk', '산책했다', now);
    await db.addDiary('2026-10-03', '일기', now);
    await db.addFind('acorn', gift: false);
    await db.addCarried('acorn', FindSource.walk, now);
    await db.savePlacements({'floor1': 'acorn'});
    await db.saveTrick(
      Trick.sit,
      const TrickProgress(attempts: 1, successes: 1, days: 1),
    );
    await db.addKnownDog(_dog('known_1_0'), const Friendship(name: '토토'), now);
    await db.addKinderPhoto(
      KinderPhotosCompanion.insert(
        day: '2026-10-03',
        scene: 'nap',
        friends: 'kong,bami',
        stage: PetStage.adult,
      ),
    );
    // 표가 새로 생겨도 여기서 지우는 걸 잊지 않게 모든 표를 본다.
    for (final t in db.allTables) {
      expect(await db.select(t).get(), isNotEmpty, reason: t.actualTableName);
    }
    await db.resetAll();
    for (final t in db.allTables) {
      expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
    }
  });
}
