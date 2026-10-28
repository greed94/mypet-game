import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/ui/play_tray.dart';

/// 늘 해내게(nextDouble 0).
class _Always implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// 간식 칭찬(아이디어 T6): 배우는 중인 개인기를 해낸 직후 간식을 주면 한 번 더 해낸 걸로 쳐서 빨리 배운다.
void main() {
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
    String? pouch = 'cheese_ball,pumpkin_ball',
    String? wish,
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
      lastSeenAt: now,
      affection: 50,
      quirk: const Value('sniffOwnerAfterGreet'),
      pawMarks: const Value('hidden'),
      treatPouch: Value(pouch),
    );
    if (wish != null) {
      pet = pet.copyWith(
        wish: Value(wish),
        wishDay: Value(dayKey(petDate(now))),
        wishDone: false,
      );
    }
    await db.savePet(pet);
    final c = PetController(db, pet, random: _Always(), clock: () => now);
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

  /// 시킨 뒤 지나가는 동작들의 속마음.
  List<String?> thoughts(PetController c, int seconds) {
    final seen = <String?>[];
    PetStep? last;
    for (var i = 0; i < seconds; i++) {
      if (!identical(c.step, last)) {
        last = c.step;
        seen.add(c.step.thought);
      }
      c.tick(1);
    }
    return seen;
  }

  /// '간식 냄새' 킁킁이 시작될 때까지 흘린다. 칭찬 기회는 그때 열린다.
  void untilSniff(PetController c) {
    for (var i = 0; i < 20 && c.step.tag != StepTag.praise; i++) {
      c.tick(1);
      now = now.add(const Duration(seconds: 1));
    }
    expect(c.step.tag, StepTag.praise);
    expect(c.step.thought, '킁킁… 간식 냄새');
  }

  test('해 보이는 동안엔 안내가 없고, 간식 냄새를 맡기 시작하면 칭찬 기회가 열린다', () async {
    final c = await make();
    c.command(Trick.sit);
    expect(c.praiseOpen, isFalse);
    untilSniff(c);
    expect(c.praiseOpen, isTrue);
    now = now.add(const Duration(seconds: 6));
    final before = c.tricks[Trick.sit]!;
    c.giveTreat();
    expect(c.tricks[Trick.sit]!.successes, before.successes + 1);
    expect(c.tricks[Trick.sit]!.attempts, before.attempts + 1);
    expect(c.praiseOpen, isFalse);
    expect(thoughts(c, 6), contains('또 시켜 줘!'));
    await pumpEventQueue(times: 20);
    expect(await events('trick'), contains("'앉아'를 해내고 간식을 받았다"));
  });

  test('세 번째가 간식 칭찬이면 그때 배우고, 폰 일기에도 그 줄이 들어간다', () async {
    final c = await make();
    c.command(Trick.sit);
    c.command(Trick.sit);
    expect(c.tricks[Trick.sit]!.learned, isFalse);
    untilSniff(c);
    c.giveTreat();
    final p = c.tricks[Trick.sit]!;
    expect(p.learned, isTrue);
    expect(p.learnedDay, '2026-10-06');
    expect(thoughts(c, 6), contains('이제 알겠어!'));
    await pumpEventQueue(times: 20);
    const line = "간식 칭찬을 받고 '앉아'를 처음으로 익혔다";
    expect(await events('trick'), contains(line));
    final diary = localDiary([
      for (final e in await db.eventsOn(now))
        (at: e.at, kind: e.kind, detail: e.detail),
    ], Random(1))!;
    expect(diary, contains(line));
  });

  test('오늘 소원이 그 개인기면 소원도 이루고, 기쁨은 간식 냄새 뒤에 온다', () async {
    final c = await make(wish: 'trick:sit');
    c.command(Trick.sit);
    expect(c.openWish, isNull);
    final seen = thoughts(c, 12);
    expect(seen, containsAllInOrder(['킁킁… 간식 냄새', '이거! 이거 하고 싶었어!']));
  });

  test('소원을 이룬 그 개인기에도 칭찬 기회는 그대로 열린다', () async {
    final c = await make(wish: 'trick:sit');
    c.command(Trick.sit);
    untilSniff(c);
    expect(c.praiseOpen, isTrue);
    final before = c.tricks[Trick.sit]!.successes;
    c.giveTreat();
    expect(c.tricks[Trick.sit]!.successes, before + 1);
  });

  test('너무 늦게 주면 그냥 간식이다', () async {
    final c = await make();
    c.command(Trick.sit);
    untilSniff(c);
    now = now.add(praiseWithin + const Duration(seconds: 1));
    expect(c.praiseOpen, isFalse);
    final before = c.tricks[Trick.sit]!.successes;
    c.giveTreat();
    expect(c.tricks[Trick.sit]!.successes, before);
  });

  test('기회가 지나면 동작이 바뀌기 전이라도 안내를 거둔다', () async {
    final c = await make();
    c.command(Trick.sit);
    untilSniff(c);
    var told = 0;
    c.addListener(() => told++);
    now = now.add(praiseWithin + const Duration(seconds: 1));
    c.tick(0.1);
    expect(c.step.tag, StepTag.praise);
    expect(told, greaterThan(0));
    expect(c.praiseOpen, isFalse);
  });

  test('주머니가 비었으면 간식 냄새를 맡지 않는다', () async {
    final empty = await make(pouch: null);
    empty.command(Trick.sit);
    expect(empty.praiseOpen, isFalse);
    expect(thoughts(empty, 6), isNot(contains('킁킁… 간식 냄새')));
  });

  test('산책 중엔 간식을 못 주니 간식 냄새도 맡지 않는다', () async {
    final c = await make();
    c.walking = true;
    c.command(Trick.sit);
    expect(thoughts(c, 8), isNot(contains('킁킁… 간식 냄새')));
    expect(c.praiseOpen, isFalse);
  });

  test('배운 개인기를 해낸 뒤엔 칭찬 안내가 없다', () async {
    final c = await make();
    for (var i = 0; i < learnAfter; i++) {
      c.command(Trick.sit);
    }
    expect(c.tricks[Trick.sit]!.learned, isTrue);
    c.command(Trick.sit);
    expect(thoughts(c, 8), isNot(contains('킁킁… 간식 냄새')));
    expect(c.praiseOpen, isFalse);
  });

  test('밤에 냄새를 맡고 다시 잠들었어도 칭찬 간식엔 깨서 먹는다', () async {
    final c = await make();
    // 같은 펫(입맛은 태어난 때로 정해진다)을 새벽 1시로 옮긴다.
    now = DateTime(2026, 10, 7, 1);
    // 제 자리에서 자고 있었다. 킁킁 뒤 걸어갈 필요 없이 바로 다시 잠든다.
    c.petX = c.sleepSpotX;
    c.step = const PetStep(Behavior.sleep, 60);
    c.command(Trick.sit);
    untilSniff(c);
    for (var i = 0; i < 6 && c.step.behavior != Behavior.sleep; i++) {
      c.tick(1);
      now = now.add(const Duration(seconds: 1));
    }
    expect(c.step.behavior, Behavior.sleep);
    expect(c.praiseOpen, isTrue);
    final before = c.tricks[Trick.sit]!.successes;
    c.giveTreat();
    expect(c.tricks[Trick.sit]!.successes, before + 1);
    expect(c.pouch, ['pumpkin_ball']);
  });

  test('말을 걸면 칭찬 기회는 지나간다', () async {
    final c = await make();
    c.command(Trick.sit);
    untilSniff(c);
    await c.talk('오늘 너무 지쳤어');
    expect(c.praiseOpen, isFalse);
    final before = c.tricks[Trick.sit]!.successes;
    c.giveTreat();
    expect(c.tricks[Trick.sit]!.successes, before);
  });

  test('공을 물고 오는 중엔 간식을 주지 않는다', () async {
    final c = await make();
    c.ball = Ball.carried;
    c.giveTreat();
    expect(c.pouch, ['cheese_ball', 'pumpkin_ball']);
    expect(c.ball, Ball.carried);
  });

  testWidgets('놀이 칸에 간식이 있으면 "간식 N"이 보이고 누르면 준다', (tester) async {
    var given = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayTray(
            tricks: const {},
            onTrick: (_) {},
            onClose: () {},
            treats: 2,
            onTreat: () => given++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('간식 2'));
    expect(given, 1);
  });
}
