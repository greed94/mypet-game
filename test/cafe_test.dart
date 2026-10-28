import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 10, 2, 14);

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

  test('문을 탭하면 카페로 가고, 손님 둘이나 셋이 있고, 왼쪽에서 걸어 들어온다', () async {
    final c = await make();
    expect(c.goToCafe(), isTrue);
    expect(c.atCafe, isTrue);
    expect(c.guests.length, inInclusiveRange(2, 3));
    expect(c.step.behavior, Behavior.walk);
    expect(c.step.targetX, 0.4);
    expect(c.bubble, '카페다!');
    // 이미 카페면 그대로 카페.
    expect(c.goToCafe(), isTrue);
  });

  test('카페에서는 걷기·앉기·킁킁·서기만 하고 잠·문 앞 기다림·밥은 없다', () async {
    final c = await make();
    c.goToCafe();
    final seen = <Behavior>{};
    for (var i = 0; i < 600; i++) {
      c.tick(1);
      seen.add(c.step.behavior);
      if (c.step.targetX case final t?) expect(t, inInclusiveRange(0.1, 0.9));
    }
    expect(seen, containsAll([Behavior.walk, Behavior.sit, Behavior.sniff]));
    expect(
      seen.difference({
        Behavior.walk,
        Behavior.sit,
        Behavior.sniff,
        Behavior.idle,
      }),
      isEmpty,
    );
    expect(c.atCafe, isTrue);
  });

  test('새벽 카페에선 한 번 졸리다고 하고 그 자리에서 꾸벅 존다', () async {
    now = DateTime(2026, 10, 2, 23, 40);
    final c = await make();
    c.step = const PetStep(Behavior.idle, 3);
    c.stats = c.stats.copyWith(energy: 90);
    expect(c.goToCafe(), isTrue);
    await pumpEventQueue(times: 50);
    final thoughts = <String>[];
    final seen = <Behavior>{};
    PetStep? last;
    for (var i = 0; i < 120; i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      // 한 단계가 여러 틱 이어지니 단계가 바뀔 때만 센다.
      if (!identical(c.step, last)) {
        if (c.step.thought case final t?) thoughts.add(t);
        last = c.step;
      }
      seen.add(c.step.behavior);
    }
    expect(thoughts.where((t) => t == '꾸벅… 나도 졸려'), hasLength(1));
    expect(seen, contains(Behavior.sleep));
    expect(c.atCafe, isTrue);
  });

  test('낮에 지치면 집에 가서 쉬자고 하고 졸다가, 기운이 돌아오면 다시 돌아다닌다', () async {
    final c = await make();
    expect(c.goToCafe(), isTrue);
    await pumpEventQueue(times: 50);
    c.stats = c.stats.copyWith(energy: 10);
    final thoughts = <String>[];
    for (var i = 0; i < 80 && c.step.behavior != Behavior.sleep; i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      if (c.step.thought case final t?) thoughts.add(t);
    }
    expect(thoughts, contains('헥헥… 집에 가서 쉴래'));
    expect(c.step.behavior, Behavior.sleep);
    c.stats = c.stats.copyWith(energy: 90);
    for (var i = 0; i < 40 && c.step.behavior == Behavior.sleep; i++) {
      c.tick(1);
    }
    expect(c.step.behavior, isNot(Behavior.sleep));
    // 같은 나들이에선 졸리다는 말을 다시 하지 않는다.
    c.stats = c.stats.copyWith(energy: 10);
    final again = <String>[];
    for (var i = 0; i < 60; i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      if (c.step.thought case final t?) again.add(t);
    }
    expect(again, isNot(contains('헥헥… 집에 가서 쉴래')));
  });

  test('집으로 오면 걸린 시간을 돌려주고 카페 일이 일기 재료에 남는다', () async {
    final c = await make();
    c.goToCafe();
    final guests = c.guests.length;
    now = now.add(const Duration(minutes: 25));
    expect(c.comeHome(), 25);
    expect(c.atCafe, isFalse);
    expect(c.step.behavior, Behavior.walk);
    expect(c.step.targetX, 0.5);
    await pumpEventQueue();
    final cafe = (await db.eventsOn(now)).where((e) => e.kind == 'cafe');
    expect(cafe.single.detail, contains('$guests마리'));
  });

  test('문을 열 때 깊이 자거나 지쳤으면 안 나가고, 아니면 깨어나서 나간다', () async {
    final c = await make();
    c.step = const PetStep(Behavior.sleep, 30);
    c.stats = c.stats.copyWith(energy: tiredEnergy - 1);
    expect(c.canGoOut(), isFalse);
    expect(c.bubble, '…쿨.');
    c.step = const PetStep(Behavior.idle, 3);
    expect(c.canGoOut(), isFalse);
    expect(c.bubble, '지금은 좀 쉬고 싶어…');
    c.stats = c.stats.copyWith(energy: 80);
    expect(c.canGoOut(), isTrue);
    expect(c.atCafe, isFalse);
  });

  test('깊이 자면 산책 버튼도 지도의 공원처럼 거절한다', () async {
    final c = await make();
    c.step = const PetStep(Behavior.sleep, 30);
    c.stats = c.stats.copyWith(energy: tiredEnergy - 1);
    expect(c.startWalk(), isFalse);
    expect(c.bubble, '…쿨.');
    expect(c.walking, isFalse);
  });

  test('지쳤으면 카페에 안 간다', () async {
    final c = await make();
    c.stats = c.stats.copyWith(energy: tiredEnergy - 1);
    expect(c.goToCafe(), isFalse);
    expect(c.atCafe, isFalse);
    expect(c.bubble, '지금은 좀 쉬고 싶어…');
  });

  test('깊이 자고 있으면 문을 탭해도 깨우지 못한다', () async {
    final c = await make();
    c.step = const PetStep(Behavior.sleep, 30);
    c.stats = c.stats.copyWith(energy: tiredEnergy - 1);
    expect(c.goToCafe(), isFalse);
    expect(c.bubble, '…쿨.');
    expect(c.step.behavior, Behavior.sleep);
  });

  test('물건을 내밀고 있으면 먼저 받으라고 하고, 창틀 물건은 상관없다', () async {
    await db.addCarried('acorn', FindSource.walk, now);
    final c = await make();
    expect(c.presenting?.source, FindSource.walk);
    expect(c.goToCafe(), isFalse);
    expect(c.bubble, '이거 먼저 받아 줘!');

    await c.receive();
    await db.addCarried('acorn', FindSource.window, now);
    c.carried = await db.allCarried();
    expect(c.presenting?.source, FindSource.window);
    expect(c.goToCafe(), isTrue);
  });

  test('카페에선 공을 안 꺼내고 물어와도 안 하지만 다른 개인기는 한다', () async {
    final c = await make();
    c.goToCafe();
    c.takeOutBall();
    expect(c.ball, Ball.none);
    c.command(Trick.fetch);
    expect(c.bubble, '집에 가서 하자!');
    expect(c.tricks[Trick.fetch], isNull);
    c.command(Trick.sit);
    expect(c.tricks[Trick.sit]?.attempts, 1);
    expect(c.atCafe, isTrue);
  });

  test('카페에서 놀자·잘 자·산책 가자고 하면 집에 가서 하자고 답하고 카페에 남는다', () async {
    final c = await make();
    c.goToCafe();
    await c.talk('놀자');
    expect(c.bubble, '집에 가서 놀자!');
    expect(c.ball, Ball.none);
    await c.talk('잘 자');
    expect(c.bubble, '집에 가서 잘래.');
    await c.talk('산책 가자');
    expect(c.bubble, '집에 가서 가자!');
    expect(c.walkProposed, isFalse);
    expect(c.atCafe, isTrue);
    await pumpEventQueue();
    final talks = (await db.eventsOn(now)).where((e) => e.kind == 'talk');
    expect(talks.map((e) => e.detail), isNot(contains(contains('문 앞으로'))));
  });

  group('친구 사이', () {
    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    test('카페에 가면 와 있는 애들과 한 칸 가까워지고, 같은 날 또 가도 그대로다', () async {
      final c = await make();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      for (final g in c.guests) {
        expect(c.friends[g.id]?.bond, Bond.stranger);
        expect(c.friends[g.id]?.days, 1);
      }
      expect(c.cafeNote, contains('낯섦'));
      expect(c.cafeNote, contains('처음 보는 애 ${c.guests.length - 1}'));
      // 입장 걷기('카페다!')가 끝난 뒤 만남 장면이 이어진다.
      expect(c.bubble, '카페다!');
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
      expect(thoughts, contains('…누구지?'));
      expect(await events('friend'), hasLength(c.guests.length));
      expect((await db.loadFriends()).length, c.guests.length);

      c.comeHome();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      for (final g in c.guests) {
        expect(c.friends[g.id]?.days, 1);
      }
      expect(await events('friend'), hasLength(c.guests.length));
    });

    test('날마다 한 칸: 낯섦 → 킁킁(친구 카드) → 놀이 → 단짝(아끼던 물건을 두고 간다)', () async {
      final c = await make();
      final ids = <String>{};
      for (var day = 0; day < 6; day++) {
        c.goToCafe();
        await pumpEventQueue(times: 50);
        ids.addAll(c.guests.map((g) => g.id));
        c.comeHome();
        now = now.add(const Duration(days: 1));
      }
      final best = c.friends.values.map((f) => f.bond.index).reduce(max);
      expect(best, greaterThanOrEqualTo(Bond.play.index));
      await pumpEventQueue(times: 50);
      final friendItems = (await db.allCarried()).where(
        (i) => i.source == FindSource.friend,
      );
      final besties = c.friends.values.where((f) => f.bond == Bond.bestie);
      expect(friendItems.length, besties.length);
      // 집에 오면 물고 내민다. 단짝 선물이면 받을 때 그 일이 남는다.
      if (besties.isNotEmpty) {
        expect(c.presenting?.source, FindSource.friend);
        final r = await c.receive();
        expect(r?.source, FindSource.friend);
        expect(await events('find'), [contains('단짝')]);
      }
    });

    test('단짝이 된 날 하루만 물건을 두고 가고, 그 뒤엔 "또 신나게 놀았다"', () async {
      final c = await make();
      final g = c.guests.isEmpty ? guestsAt(now).first : guestsAt(now).first;
      c.friends[g.id] = const Friendship(
        bond: Bond.play,
        days: 3,
        lastDay: 'x',
      );
      await db.saveFriend(g.id, c.friends[g.id]!);
      // 그 애가 있는 날까지 넘긴다.
      for (var i = 0; i < 30 && !guestsAt(now).any((x) => x.id == g.id); i++) {
        now = now.add(const Duration(days: 1));
      }
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.friends[g.id]?.bond, Bond.bestie);
      expect(
        (await db.allCarried()).where((i) => i.source == FindSource.friend),
        hasLength(1),
      );
      expect(await events('friend'), anyElement(contains('단짝이 됐다')));
      c.comeHome();
      await c.receive();

      now = now.add(const Duration(days: 1));
      for (var i = 0; i < 30 && !guestsAt(now).any((x) => x.id == g.id); i++) {
        now = now.add(const Duration(days: 1));
      }
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.friends[g.id]?.bond, Bond.bestie);
      expect(c.friends[g.id]?.days, 5);
      expect(
        (await db.allCarried()).where((i) => i.source == FindSource.friend),
        isEmpty,
      );
      expect(await events('friend'), anyElement(contains('또 신나게')));
      expect(await events('friend'), isNot(anyElement(contains('단짝이 됐다'))));
    });

    test('친구 카드는 만남 장면이 끝날 때 잡힌다', () async {
      final c = await make();
      final g = guestsAt(now).first;
      c.friends[g.id] = const Friendship(
        bond: Bond.stranger,
        days: 1,
        lastDay: 'x',
      );
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.friends[g.id]?.bond, Bond.sniff);
      // 입장 걷기·다가가기·킁킁이 끝나기 전엔 카드가 없다.
      expect(c.pendingCard, isNull);
      for (var i = 0; i < 60 && c.step.tag != StepTag.meet; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
      expect(c.step.tag, StepTag.meet);
      expect(c.pendingCard?.id, g.id);
    });

    test('만남 처리 중에 집으로 가면 카드·카페 글은 남지 않고 사이는 저장된다', () async {
      final c = await make();
      c.goToCafe();
      // 첫 애가 저장되는 사이(처리 도중)에 집으로 간다.
      for (var i = 0; i < 200 && (await db.loadFriends()).isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      c.comeHome();
      await pumpEventQueue(times: 50);
      expect(c.pendingCard, isNull);
      expect(c.cafeNote, '');
      expect(c.spot, Spot.home);
      expect(
        (await db.loadFriends()).values.map((f) => f.bond),
        everyElement(Bond.stranger),
      );
    });

    test('밤 카페에선 자는 애 옆에 조용히 앉고, 개인기를 해내도 따라 하지 않는다', () async {
      now = DateTime(2026, 10, 2, 22);
      final c = await make();
      final g = guestsAt(now).first;
      c.friends[g.id] = const Friendship(
        bond: Bond.play,
        days: 3,
        lastDay: 'x',
      );
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final seen = <Behavior>{};
      for (var i = 0; i < 60 && c.step.tag != StepTag.meet; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
        seen.add(c.step.behavior);
      }
      expect(c.step.tag, StepTag.meet);
      // 놀이 → 단짝으로 한 칸 올라 이름을 부르며 조용히 앉는다.
      expect(c.step.thought, endsWith('자네. 옆에 있을래.'));
      expect(seen, isNot(contains(Behavior.happy)));
      c.stats = c.stats.copyWith(energy: 90);
      c.tricks[Trick.sit] = const TrickProgress(
        attempts: 9,
        successes: 9,
        days: 3,
      );
      for (var i = 0; i < 3; i++) {
        c.command(Trick.sit);
      }
      expect(c.mimicTrick, isNull);
      for (var i = 0; i < 30; i++) {
        c.tick(1);
      }
      expect(c.mimicGen, 0);
    });

    test('개인기를 해내면 친구는 펫의 칭찬 뒤에 따라 하기 시작한다', () async {
      final c = await make();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final g = c.guests.first;
      c.friends[g.id] = const Friendship(
        bond: Bond.play,
        days: 3,
        lastDay: 'x',
      );
      c.stats = c.stats.copyWith(energy: 90);
      c.tricks[Trick.spin] = const TrickProgress(
        attempts: 9,
        successes: 9,
        days: 3,
      );
      for (var i = 0; i < 3 && c.mimicTrick == null; i++) {
        c.command(Trick.spin);
      }
      expect(c.mimicTrick, Trick.spin);
      expect(c.mimicGen, 0);
      for (var i = 0; i < 30 && c.mimicGen == 0; i++) {
        c.tick(1);
      }
      expect(c.mimicGen, 1);
      expect(c.step.tag, StepTag.mimic);
      c.tick(1.1);
      expect(c.bubble, '따라 하네! 나 잘하지?');
      // 카페를 나갔다 오면 지난 개인기를 새 손님이 따라 하지 않는다.
      c.comeHome();
      expect(c.mimicTrick, isNull);
    });

    test('이어 하기를 해도 친구가 마지막 개인기를 따라 한다', () async {
      final c = await make();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final g = c.guests.first;
      c.friends[g.id] = const Friendship(
        bond: Bond.play,
        days: 3,
        lastDay: 'x',
      );
      c.stats = c.stats.copyWith(energy: 90);
      const three = TrickProgress(
        attempts: 6,
        successes: 6,
        days: 3,
        lastDay: '2026-10-01',
      );
      c.tricks[Trick.sit] = three;
      c.tricks[Trick.spin] = three;
      expect(await c.talk('앉아 돌아'), TalkOutcome.command);
      expect(c.mimicTrick, Trick.spin);
    });

    test('창밖 친구가 지나갈 때 한 단계짜리 반응 중이면 끊지 않는다', () async {
      final c = await make();
      final g = cafeRegulars.first;
      c.friends[g.id] = Friendship(
        bond: Bond.sniff,
        days: 2,
        lastDay: dayKey(petDate(now).subtract(const Duration(days: 1))),
      );
      now = DateTime(2026, 10, 2, 14);
      while (windowPass(now, c.pet.id) == null) {
        now = now.add(const Duration(seconds: 1));
      }
      c.step = const PetStep(Behavior.happy, 2.5);
      c.tick(0.5);
      expect(c.step.behavior, Behavior.happy);
      expect(c.windowPasser?.id, g.id);
    });

    test('날씨 탓에 제 발로 누워 쉬는 중이면 창밖 친구를 보러 가고, 위로하느라 누운 거면 두고 본다', () async {
      final g = cafeRegulars.first;
      final yesterday = dayKey(petDate(now).subtract(const Duration(days: 1)));
      now = DateTime(2026, 10, 2, 14);
      Future<PetController> lying({required bool everyday}) async {
        final c = await make();
        c.friends[g.id] = Friendship(
          bond: Bond.sniff,
          days: 2,
          lastDay: yesterday,
        );
        c.step = const PetStep(Behavior.lieBeside, 10);
        c.everyday = everyday;
        return c;
      }

      final resting = await lying(everyday: true);
      while (windowPass(now, resting.pet.id) == null) {
        now = now.add(const Duration(seconds: 1));
      }
      resting.tick(0.5);
      expect(resting.step.behavior, Behavior.watchWindow);

      final comforting = await lying(everyday: false);
      comforting.tick(0.5);
      expect(comforting.step.behavior, Behavior.lieBeside);
      expect(comforting.windowPasser?.id, g.id);
    });

    test('처음 서로 킁킁한 날 친구 카드가 잡히고, 이름을 붙이면 일기가 그 이름으로 부른다', () async {
      final c = await make();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.pendingCard, isNull);
      final first = c.guests.first;
      c.comeHome();
      now = now.add(const Duration(days: 1));
      // 같은 애가 있을 때까지 날을 넘긴다.
      for (
        var i = 0;
        i < 20 && !guestsAt(now).any((g) => g.id == first.id);
        i++
      ) {
        now = now.add(const Duration(days: 1));
      }
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(c.friends[first.id]?.bond, Bond.sniff);
      for (var i = 0; i < 60 && c.pendingCard == null; i++) {
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
      expect(c.pendingCard?.id, first.id);
      c.comeHome();
      expect(c.pendingCard, isNull);

      await c.nameFriend(first.id, ' 코코 ');
      expect(c.friends[first.id]?.name, '코코');
      expect(c.friends[first.id]?.bond, Bond.sniff);
      expect((await db.loadFriends())[first.id]?.name, '코코');
      now = now.add(const Duration(days: 1));
      for (
        var i = 0;
        i < 20 && !guestsAt(now).any((g) => g.id == first.id);
        i++
      ) {
        now = now.add(const Duration(days: 1));
      }
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(await events('friend'), anyElement(contains('코코')));
      await c.nameFriend(first.id, '');
      expect(c.friends[first.id]?.name, isNull);
    });

    test('놀이 사이가 넘는 친구가 있을 때 개인기를 해내면 따라 하고, 처음은 일기에 남는다', () async {
      final c = await make();
      c.goToCafe();
      await pumpEventQueue(times: 50);
      final g = c.guests.first;
      c.friends[g.id] = const Friendship(
        bond: Bond.play,
        days: 3,
        lastDay: 'x',
      );
      c.stats = c.stats.copyWith(energy: 90);
      c.tricks[Trick.sit] = const TrickProgress(
        attempts: 9,
        successes: 9,
        days: 3,
      );
      // 세 번째 시도는 꼭 해내므로 늦어도 세 번 안에 따라 한다.
      for (var i = 0; i < 3 && c.mimicTrick == null; i++) {
        c.command(Trick.sit);
      }
      expect(c.mimicTrick, Trick.sit);
      for (var i = 0; i < 30 && c.mimicGen == 0; i++) {
        c.tick(1);
      }
      expect(c.mimicGen, 1);
      await pumpEventQueue(times: 20);
      expect(await events('friend_trick'), [contains(g.look)]);

      // 낯선 애뿐이면 해내도 따라 하지 않는다.
      c.friends[g.id] = const Friendship(
        bond: Bond.stranger,
        days: 1,
        lastDay: 'x',
      );
      c.mimicTrick = null;
      for (var i = 0; i < 3; i++) {
        c.command(Trick.sit);
      }
      expect(c.mimicTrick, isNull);
      for (var i = 0; i < 30; i++) {
        c.tick(1);
      }
      expect(c.mimicGen, 1);
    });

    test('어제 만난 애가 낮에 창밖을 지나가면 한가할 때 창가로 가서 본다', () async {
      final c = await make();
      final g = cafeRegulars.first;
      c.friends[g.id] = Friendship(
        bond: Bond.sniff,
        days: 2,
        lastDay: dayKey(petDate(now).subtract(const Duration(days: 1))),
      );
      // 지나가는 순간을 찾는다(펫 번호에 따라 때가 다르다).
      now = DateTime(2026, 10, 2, 14);
      while (windowPass(now, c.pet.id) == null) {
        now = now.add(const Duration(seconds: 1));
      }
      c.step = const PetStep(Behavior.idle, 3);
      c.tick(0.5);
      expect(c.windowPasser?.id, g.id);
      expect(c.windowPassProgress, isNotNull);
      expect(c.step.behavior, Behavior.watchWindow);
      expect(c.bubble, '어? 그 애다!');
      now = now.add(const Duration(seconds: 8));
      c.tick(0.5);
      expect(c.windowPasser, isNull);
      await pumpEventQueue();
      expect(await events('friend_window'), [contains(g.look)]);
      expect(c.spot, Spot.home);
    });

    test('오늘 만난 애들은 밤 꿈 풍선에 나온다', () async {
      final c = await make();
      expect(c.metToday, isEmpty);
      c.goToCafe();
      await pumpEventQueue(times: 50);
      expect(
        c.metToday.map((g) => g.id).toSet(),
        c.guests.map((g) => g.id).toSet(),
      );
      now = now.add(const Duration(days: 1));
      expect(c.metToday, isEmpty);
    });
  });

  test('카페에 있는 동안 화면을 다시 켜도 집에 온 반김을 하지 않고 카페에 그대로 있다', () async {
    final c = await make();
    c.goToCafe();
    c.sleepApp();
    now = now.add(const Duration(hours: 2));
    expect(c.wake(), Greeting.none);
    expect(c.atCafe, isTrue);
    expect(c.step.behavior, isNot(Behavior.waitAtDoor));
  });
}
