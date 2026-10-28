import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/pet/wish.dart';

void main() {
  late AppDatabase db;
  // 2026-10-06은 화요일이다.
  var now = DateTime(2026, 10, 6, 14);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 6, 14);
  });
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  /// [wish]를 주면 오늘의 소원으로 정해 둔 채 연다. [pouch]는 간식 주머니(쉼표로).
  Future<PetController> make({String? wish, String? pouch}) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    pet = pet.copyWith(
      lastSeenAt: now,
      treatPouch: Value(pouch),
      likeTaste: const Value(Taste.round),
      dislikeTaste: const Value(Taste.smelly),
    );
    if (wish != null) {
      pet = pet.copyWith(
        wish: Value(wish),
        wishDay: Value(dayKey(petDate(now))),
        wishDone: false,
      );
    }
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
    return c;
  }

  Future<List<String>> events(String kind) async => [
    for (final e in await db.eventsOn(now))
      if (e.kind == kind) e.detail,
  ];

  /// 걷기는 닿으면, 나머지는 시간이 지나면 다음으로.
  void run(PetController c, int steps) {
    for (var i = 0; i < steps; i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
  }

  test('열면 오늘의 소원을 고르고 저장한다. 다시 열어도 같고, 한가할 때 속마음으로 한 번 말한다', () async {
    final c = await make();
    final w = c.wish;
    expect(w, isNotNull);
    expect((await db.loadPet())!.wishDay, '2026-10-06');
    final again = PetController(db, c.pet, random: Random(9), clock: () => now);
    again.wake();
    await again.collected;
    expect(again.wish?.encode(), w!.encode());

    final said = <String>[];
    PetStep? last;
    for (var i = 0; i < 90; i++) {
      run(c, 1);
      if (!identical(c.step, last)) {
        if (c.step.thought case final t?) said.add(t);
        last = c.step;
      }
    }
    expect(said.where((t) => t == wishThought(w)), hasLength(1));
  });

  test('공놀이 소원: 던진 공을 물어 오면 이뤄지고, 하던 흐름 뒤에 기뻐한다', () async {
    final c = await make(wish: 'ball');
    c.step = const PetStep(Behavior.idle, 3);
    c.takeOutBall();
    c.arrived();
    // 꺼내 놓기만 해서는 안 이뤄진다.
    expect(c.openWish?.kind, WishKind.ball);
    expect(c.throwBall(), isTrue);
    c.ballLanded();
    c.arrived();
    c.tick(0.5);
    c.arrived();
    expect(c.step.tag, StepTag.drop);
    expect(c.openWish, isNull);
    expect(c.wish?.kind, WishKind.ball);
    final thoughts = <String>[];
    for (var i = 0; i < 8; i++) {
      c.tick(1);
      if (c.step.thought case final t?) thoughts.add(t);
    }
    expect(thoughts, contains('이거! 이거 하고 싶었어!'));
    await pumpEventQueue(times: 20);
    expect(await events('wish'), ['오늘 소원이던 공놀이를 했다']);
    expect((await db.loadPet())!.wishDone, isTrue);
  });

  test('쓰다듬기 소원: 세 번(연타는 한 번) 쓰다듬으면 이뤄진다', () async {
    final c = await make(wish: 'cuddle');
    for (var i = 0; i < 5; i++) {
      c.interact(Interaction.pet);
    }
    expect(c.openWish, isNotNull);
    now = now.add(const Duration(seconds: 5));
    c.interact(Interaction.pet);
    expect(c.openWish, isNotNull);
    now = now.add(const Duration(seconds: 5));
    c.interact(Interaction.pet);
    expect(c.openWish, isNull);
    expect(await events('wish'), ['오늘 소원대로 주인이 많이 쓰다듬어 줬다']);
  });

  test('깊이 잠든 펫을 쓰다듬은 건 쓰다듬기 소원에 세지 않는다', () async {
    now = DateTime(2026, 10, 6, 23, 30);
    final c = await make(wish: 'cuddle');
    c.step = const PetStep(Behavior.sleep, 60);
    for (var i = 0; i < 4; i++) {
      now = now.add(const Duration(seconds: 5));
      c.interact(Interaction.pet);
      c.step = const PetStep(Behavior.sleep, 60);
    }
    expect(c.openWish?.kind, WishKind.cuddle);
    expect(await events('wish'), isEmpty);
  });

  test('친구 소원: 그 애가 와 있는 카페에 가면 만남 장면 뒤에 기뻐한다', () async {
    final g = guestsAt(now).first;
    final c = await make(wish: 'friend:${g.id}');
    c.friends[g.id] = const Friendship(bond: Bond.play, days: 3, lastDay: 'x');
    expect(c.wishFriend?.id, g.id);
    c.goToCafe();
    await pumpEventQueue(times: 50);
    expect(c.openWish, isNull);
    // 만남 장면(meet)이 기뻐하기보다 먼저다.
    final tags = <StepTag>[];
    final thoughts = <String>[];
    for (var i = 0; i < 60; i++) {
      run(c, 1);
      tags.add(c.step.tag);
      if (c.step.thought case final t?) thoughts.add(t);
      if (thoughts.contains('이거! 이거 하고 싶었어!')) break;
    }
    expect(tags, contains(StepTag.meet));
    expect(thoughts.last, '이거! 이거 하고 싶었어!');
    expect((await events('wish')).single, contains('카페에서 만났다'));
  });

  test('다른 애만 있으면 친구 소원은 안 이뤄진다', () async {
    final present = guestsAt(now).map((g) => g.id).toSet();
    final absent = cafeRegulars.firstWhere((g) => !present.contains(g.id));
    final c = await make(wish: 'friend:${absent.id}');
    c.goToCafe();
    await pumpEventQueue(times: 50);
    expect(c.openWish?.target, absent.id);
  });

  test('유치원·간식 소원: 유치원에 들어가거나 간식을 먹으면 이뤄진다(냄새만 맡으면 아니다)', () async {
    final kinder = await make(wish: 'kinder');
    expect(kinder.goToKindergarten(), isTrue);
    expect(kinder.openWish, isNull);
    await pumpEventQueue(times: 50);
    await db.close();

    db = AppDatabase(NativeDatabase.memory());
    // 싫어하는 맛(냄새만 맡음) 먼저, 그다음 좋아하는 맛.
    final treat = await make(wish: 'treat', pouch: 'jerky,cheese_ball');
    treat.step = const PetStep(Behavior.idle, 3);
    treat.giveTreat();
    expect(treat.openWish?.kind, WishKind.treat);
    treat.giveTreat();
    expect(treat.openWish, isNull);
    expect(await events('wish'), ['오늘 소원이던 간식을 먹었다']);
  });

  test('날이 바뀌면(새벽 5시) 새 소원을 고르고, 들어준 표시는 지워진다', () async {
    final c = await make(wish: 'ball');
    c.step = const PetStep(Behavior.idle, 3);
    c.interact(Interaction.pet);
    now = DateTime(2026, 10, 7, 5, 1);
    for (var i = 0; i < 61; i++) {
      c.tick(1);
    }
    expect((await db.loadPet())!.wishDay, '2026-10-07');
    expect(c.wish, isNotNull);
    expect(c.pet.wishDone, isFalse);
  });

  test('어제 소원과 같은 종류는 오늘 고르지 않는다', () async {
    for (final k in ['ball', 'treat', 'cuddle', 'kinder']) {
      // 앞 반복의 저장이 끝난 뒤에 닫는다.
      await pumpEventQueue(times: 100);
      await db.close();
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 6, 14);
      final c = await make(wish: k);
      now = DateTime(2026, 10, 7, 9);
      for (var i = 0; i < 61; i++) {
        c.tick(1);
      }
      expect(c.pet.wishDay, '2026-10-07');
      expect(c.wish?.kind.name, isNot(k));
    }
  });

  test('AI 반김에는 요일·시각과 오늘 바라는 것이 들어가고 친구 이름은 안 들어간다', () async {
    final sent = <http.Request>[];
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    pet = pet.copyWith(
      lastSeenAt: now.subtract(const Duration(hours: 6)),
      wish: const Value('friend:known_1_0'),
      wishDay: Value(dayKey(petDate(now))),
    );
    await db.savePet(pet);
    await db.saveFriend('known_1_0', const Friendship(name: '토토'));
    final c = PetController(
      db,
      pet,
      random: Random(1),
      clock: () => now,
      brain: AiBrain(
        baseUrl: 'https://pc/v1',
        model: 'm',
        apiKey: 'k',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content':
                          '{"mood_delta":1,"affection_delta":0,"action":"happy","thought":"왔다!","memory":null}',
                    },
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    c.wake();
    await c.collected;
    await pumpEventQueue(times: 50);
    final prompt = sent
        .map((r) => utf8.decode(r.bodyBytes))
        .firstWhere((b) => b.contains('돌아왔다'));
    expect(prompt, contains('6시간 만에'));
    expect(prompt, contains('화요일 14시'));
    expect(prompt, contains('오늘 바라는 것: 카페 친구 만나기'));
    expect(prompt, contains('하고 반겼으니 다른 말로'));
    expect(prompt, isNot(contains('토토')));
  });

  test('소원을 안 들어줘도 아무 일 없다(벌·일기 없음)', () async {
    final c = await make(wish: 'kinder');
    final before = c.stats;
    run(c, 30);
    expect(c.stats.affection, before.affection);
    expect(await events('wish'), isEmpty);
    expect(c.openWish?.kind, WishKind.kinder);
  });

  test('금요일 발표회 소원은 도장을 받으면 이뤄진다', () async {
    now = DateTime(2026, 10, 9, 10);
    final c = await make(wish: 'recital');
    c.tricks[Trick.sit] = const TrickProgress(
      attempts: 3,
      successes: 3,
      days: 1,
    );
    c.goToKindergarten();
    expect(c.startRecital(), isTrue);
    for (var i = 0; i < 60 && c.step.tag != StepTag.stamp; i++) {
      run(c, 1);
    }
    expect(c.openWish, isNull);
    expect((await events('wish')).single, contains('발표회'));
  });

  test('개인기 소원은 그 개인기를 해내면 이뤄지고, 다른 개인기로는 안 된다', () async {
    final c = await make(wish: 'trick:sit');
    c.tricks[Trick.sit] = const TrickProgress(
      attempts: 2,
      successes: 1,
      days: 1,
    );
    c.tricks[Trick.down] = const TrickProgress(
      attempts: 2,
      successes: 1,
      days: 1,
    );
    c.step = const PetStep(Behavior.idle, 3);
    for (var i = 0; i < 6 && c.tricks[Trick.down]!.successes < 2; i++) {
      c.command(Trick.down);
    }
    expect(c.openWish?.kind, WishKind.trick);
    for (var i = 0; i < 6 && c.openWish != null; i++) {
      c.command(Trick.sit);
    }
    expect(c.openWish, isNull);
    await pumpEventQueue(times: 20);
    expect(await events('wish'), ["오늘 소원이던 '앉아' 연습을 했다"]);
  });

  test('"뭐 하고 싶어?"엔 아침 풍선과 같은 말로 답하고, 이룬 뒤엔 벌써 이뤘다고, 자면 쿨', () async {
    final c = await make(wish: 'ball');
    c.step = const PetStep(Behavior.idle, 3);
    expect(await c.talk('뭐 하고 싶어?'), TalkOutcome.command);
    expect(c.step.thought, wishThought(const Wish(WishKind.ball)));
    c.takeOutBall();
    c.arrived();
    c.throwBall();
    c.ballLanded();
    c.arrived();
    c.tick(0.5);
    c.arrived();
    expect(c.openWish, isNull);
    c.step = const PetStep(Behavior.idle, 3);
    await c.talk('뭐 하고 싶어?');
    expect(c.step.thought, '오늘 소원은 벌써 이뤘어!');
    now = DateTime(2026, 10, 7, 1);
    c.step = const PetStep(Behavior.sleep, 30);
    await c.talk('소원이 뭐야');
    expect(c.step.behavior, Behavior.sleep);
    expect(c.bubble, '…쿨.');
  });
}
