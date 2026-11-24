import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/sleep_spot.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';

/// 확률을 고정한다. 0이면 늘 성공, 0.99면 늘 실패(세 번째 봐주기만 성공).
class _Fixed implements Random {
  _Fixed(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 9, 28, 14);
  late List<http.Request> sent;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 28, 14);
    sent = [];
  });
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  /// 물고 오는 공을 내려놓을 때까지(달리기는 닿은 걸로). 펫 버릇(놓기 전 한 바퀴)이 끼어도 된다.
  void untilDrop(PetController c) {
    for (var i = 0; i < 10 && c.step.tag != StepTag.drop; i++) {
      if (c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(0.5);
      }
    }
  }

  Future<PetController> make({
    Random? random,
    http.Response Function(http.Request)? respond,
    double affection = 40,
  }) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    pet = pet.copyWith(affection: affection);
    await db.savePet(pet);
    return PetController(
      db,
      pet,
      brain: respond == null
          ? null
          : AiBrain(
              baseUrl: 'https://pc/v1',
              model: 'm',
              apiKey: 'k',
              client: MockClient((req) async {
                sent.add(req);
                return respond(req);
              }),
            ),
      random: random ?? Random(1),
      clock: () => now,
    );
  }

  /// 지금 동작이 끝나고 다음 동작을 고를 때까지(최대 1분) 1초씩 흘린다. 틱은 1초씩만 간다.
  void settle(PetController c) {
    for (var i = 0; i < 60 && !c.pottyUrge; i++) {
      c.tick(1);
    }
  }

  http.Response ok(String content) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
          },
        ],
      }),
    ),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('개인기', () {
    test('이름만 부르면 AI를 부르지 않고 이름 연습이 되고, 세 번 알아들으면 매번 달려온다', () async {
      final c = await make(respond: (_) => ok('{}'), random: _Fixed(0));
      c.wake();
      for (var i = 0; i < 3; i++) {
        expect(await c.talk('콩이야!'), TalkOutcome.command);
      }
      expect(sent, isEmpty);
      expect(c.tricks[Trick.name]?.learned, isTrue);
      expect(c.step.behavior, Behavior.run);
      await pumpEventQueue();
      expect((await db.loadTricks())[Trick.name]?.successes, 3);
      final kinds = (await db.eventsOn(now)).map((e) => e.detail);
      expect(kinds, contains('내 이름이 콩이인 걸 알았다'));
    });

    test('"물어와"를 해내면 공이 없을 땐 상자에서 물고 오고, 던진 공은 쫓아간다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      // 낮잠 중이어도 공은 떨어뜨리지 않고 바로 뛰어간다.
      c.step = const PetStep(Behavior.sleep, 20);
      c.command(Trick.fetch);
      expect(c.ball, Ball.carried);
      expect(c.step.tag, StepTag.carry);
      c.arrived();
      expect(c.ball, Ball.ready);
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.command(Trick.fetch);
      expect(c.step.tag, StepTag.chase);
      expect(c.tricks[Trick.fetch]?.successes, 2);
    });

    test('쉬가 마려우면 킁킁대고, 패드로 데려가면 거기서 하고 한 번 배운다', () async {
      final c = await make(random: _Fixed(0.5));
      c.wake();
      // 처음 켠 날이라 마렵지만, 연 직후 반김·발견 카드가 지나갈 때까지는 참는다.
      expect(c.pottyUrge, isFalse);
      now = now.add(const Duration(seconds: 30));
      settle(c);
      expect(c.pottyUrge, isFalse);
      now = now.add(const Duration(seconds: 30));
      // 발견 카드나 설정이 방을 가리는 동안도 참는다.
      c.uiBusy = true;
      settle(c);
      expect(c.pottyUrge, isFalse);
      c.uiBusy = false;
      settle(c);
      expect(c.pottyUrge, isTrue);
      expect(c.step.tag, StepTag.urge);
      c.goToPad();
      expect(c.pottyUrge, isFalse);
      expect(c.step.targetX, padX);
      expect(c.tricks[Trick.potty]?.successes, 1);
      expect(c.puddleX, isNull);
      await pumpEventQueue();
      expect(
        (await db.eventsOn(now)).map((e) => e.detail),
        contains('주인이 패드로 데려가 줘서 거기에 쉬했다'),
      );
      // 세 시간 안에는 다시 마렵지 않다.
      settle(c);
      expect(c.pottyUrge, isFalse);
    });

    test('킁킁대는 동안 아무도 안 데려가면 그 자리에서 하고 자국이 잠시 남는다. 배운 뒤엔 혼자 패드로 간다', () async {
      final c = await make(random: _Fixed(0.5));
      c.wake();
      now = now.add(const Duration(seconds: 60));
      settle(c);
      expect(c.pottyUrge, isTrue);
      c.petX = 0.3;
      var guard = 0;
      while (c.pottyUrge && guard++ < 20) {
        c.tick(c.step.seconds + 0.1);
      }
      expect(c.pottyUrge, isFalse);
      expect(c.puddleX, 0.3);
      expect(c.tricks[Trick.potty]?.attempts, 1);
      expect(c.tricks[Trick.potty]?.successes, 0);
      // 자국은 1분 반 뒤에 사라진다(틱은 1초씩만 흐른다).
      now = now.add(const Duration(minutes: 2));
      for (var i = 0; i < 61; i++) {
        c.tick(1);
      }
      expect(c.puddleX, isNull);

      // 배운 뒤: 세 시간 뒤 다시 마려우면 혼자 패드로 간다.
      c.tricks[Trick.potty] = const TrickProgress(attempts: 4, successes: 3);
      now = now.add(const Duration(hours: 3));
      settle(c);
      expect(c.pottyUrge, isTrue);
      guard = 0;
      while (c.pottyUrge && guard++ < 20) {
        c.tick(c.step.seconds + 0.1);
      }
      expect(c.step.targetX, padX);
      expect(c.puddleX, isNull);
      expect(c.tricks[Trick.potty]?.successes, 4);
    });

    test('킁킁대는 중에 쓰다듬으면 버튼이 사라지고, 2분 뒤 다시 마렵다', () async {
      final c = await make(random: _Fixed(0.5));
      c.wake();
      now = now.add(const Duration(seconds: 60));
      settle(c);
      expect(c.pottyUrge, isTrue);
      c.interact(Interaction.pet);
      expect(c.pottyUrge, isFalse);
      c.goToPad();
      expect(c.tricks[Trick.potty], isNull);
      // 바로는 다시 마렵지 않고, 2분 뒤에는 다시.
      settle(c);
      expect(c.pottyUrge, isFalse);
      now = now.add(const Duration(minutes: 3));
      settle(c);
      expect(c.pottyUrge, isTrue);
    });

    test('창틀에 떨어진 물건이 있어도 쉬는 마렵다', () async {
      await db.addCarried('acorn', FindSource.window, now);
      final c = await make(random: _Fixed(0.5));
      c.wake();
      await c.collected;
      expect(c.presenting?.source, FindSource.window);
      now = now.add(const Duration(seconds: 60));
      settle(c);
      expect(c.pottyUrge, isTrue);
    });

    test('던진 공을 "물어와"로 가져오면 보상은 공놀이 몫 한 번뿐이고 칭찬은 내려놓은 뒤에 한다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      c.step = const PetStep(Behavior.idle, 3);
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      final care = c.careScore;
      c.command(Trick.fetch);
      expect(c.careScore, care);
      c.arrived();
      untilDrop(c);
      expect(c.step.tag, StepTag.drop);
      expect(c.careScore, care + carePlay);
      c.tick(1.1);
      expect(c.step.behavior, Behavior.happy);
      expect(c.step.thought, isNot('또 던져 줘!'));
    });

    test(
      '던진 공을 물고 오는 중에 "물어와"라고 해도 공을 떨어뜨리지 않고, 공놀이 보상과 개인기 연습이 둘 다 남는다',
      () async {
        final c = await make(random: _Fixed(0.99));
        c.wake();
        c.step = const PetStep(Behavior.idle, 3);
        c.takeOutBall();
        c.arrived();
        expect(c.throwBall(), isTrue);
        c.ballLanded();
        c.arrived();
        expect(c.ball, Ball.carried);
        expect(c.step.tag, StepTag.carry);
        final care = c.careScore;
        final tries = c.tricks[Trick.fetch]?.attempts ?? 0;
        // 확률은 늘 실패지만 이미 물어 오는 중이라 해낸 걸로 친다.
        c.command(Trick.fetch);
        expect(c.ball, Ball.carried);
        expect(c.step.tag, StepTag.carry);
        expect(c.tricks[Trick.fetch]?.attempts, tries + 1);
        expect(c.tricks[Trick.fetch]?.successes, 1);
        expect(c.careScore, care);
        untilDrop(c);
        expect(c.step.tag, StepTag.drop);
        expect(c.careScore, care + carePlay);
        c.tick(1.1);
        expect(c.step.behavior, Behavior.happy);
        expect(c.step.thought, isNot('또 던져 줘!'));
      },
    );

    test('상자에서 공을 물고 오는 중에 "물어와"를 해내면 개인기 보상이 빠지지 않는다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      c.step = const PetStep(Behavior.idle, 3);
      c.takeOutBall();
      expect(c.ball, Ball.carried);
      final mood = c.stats.mood;
      c.command(Trick.fetch);
      expect(c.tricks[Trick.fetch]?.successes, 1);
      expect(c.stats.mood, greaterThan(mood));
    });

    test('공을 가져오는 도중에도 물어와 한 번의 연습 결과를 즉시 알린다', () async {
      final c = await make(random: _Fixed(0.99));
      c.wake();
      await c.collected;
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      expect(c.ball, Ball.carried);
      final successesSeen = <int>[];
      c.addListener(
        () => successesSeen.add(c.tricks[Trick.fetch]?.successes ?? 0),
      );
      c.command(Trick.fetch);
      expect(successesSeen, contains(1));
      expect(c.step.tag, StepTag.carry);
    });

    test('다른 개인기 뒤 물어와를 연타하면 성공 세 번에 첫 별이 저장되고 놀이를 끝낼 수 있다', () async {
      final c = await make(random: _Fixed(0.99));
      c.wake();
      await c.collected;
      c.takeOutBall();
      c.arrived();
      c.command(Trick.sit);
      c.command(Trick.jump);
      for (var tap = 1; tap <= 9; tap++) {
        final outcome = c.command(Trick.fetch);
        final progress = c.tricks[Trick.fetch]!;
        expect(progress.attempts, tap);
        expect(progress.successes, tap ~/ 3);
        expect(progress.stars, tap == 9 ? 1 : 0);
        expect(outcome, switch (tap) {
          3 || 6 => TrickCommandOutcome.succeeded,
          9 => TrickCommandOutcome.learned,
          _ => TrickCommandOutcome.missed,
        });
      }
      c.putBallAway();
      expect(c.ball, Ball.none);
      await pumpEventQueue();
      final saved = (await db.loadTricks())[Trick.fetch]!;
      expect(saved.successes, 3);
      expect(saved.stars, 1);
    });

    test('집 밖이거나 기운이 부족할 때 물어와가 집계되지 않은 이유를 구별한다', () async {
      final c = await make();
      c.wake();
      await c.collected;
      expect(c.startWalk(), isTrue);
      expect(c.command(Trick.fetch), TrickCommandOutcome.away);
      c.endWalk();
      c.stats = c.stats.copyWith(energy: tiredEnergy - 1);
      expect(c.command(Trick.fetch), TrickCommandOutcome.tired);
      expect(c.tricks[Trick.fetch], isNull);
    });

    test('물어와 도중 놀이를 끝내면 다음 공놀이에 이전 명령의 칭찬이 남지 않는다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      await c.collected;
      c.takeOutBall();
      c.arrived();
      c.command(Trick.fetch);
      expect(c.step.tag, StepTag.chase);
      c.putBallAway();
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      untilDrop(c);
      expect(c.step.tag, StepTag.drop);
      c.tick(1);
      expect(c.step.thought, '또 던져 줘!');
    });

    test('"점프"는 폴짝 뛰는 동작이다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      c.step = const PetStep(Behavior.idle, 3);
      c.command(Trick.jump);
      expect(c.step.behavior, Behavior.jump);
      expect(c.stepElapsed, 0);
      c.tick(0.5);
      expect(c.stepElapsed, closeTo(0.5, 0.001));
    });

    test('"앉아"는 AI를 부르지 않고 바로 하고, 연습 기록이 남는다', () async {
      final c = await make(respond: (_) => ok('{}'), random: _Fixed(0));
      c.wake();
      expect(await c.talk('콩이야 앉아!'), TalkOutcome.command);
      expect(sent, isEmpty);
      expect(c.step.behavior, Behavior.sit);
      expect(c.tricks[Trick.sit]?.successes, 1);
      await pumpEventQueue();
      expect((await db.loadTricks())[Trick.sit]?.attempts, 1);
    });

    test('두 번 못 하면 세 번째엔 해내고, 세 번 해내면 배운 날로 일기에 남는다', () async {
      final c = await make(random: _Fixed(0.99));
      c.wake();
      c.command(Trick.spin);
      c.command(Trick.spin);
      expect(c.tricks[Trick.spin]?.successes, 0);
      c.command(Trick.spin);
      expect(c.tricks[Trick.spin]?.successes, 1);
      for (var i = 0; i < 6; i++) {
        c.command(Trick.spin);
      }
      expect(c.tricks[Trick.spin]?.learned, isTrue);
      await pumpEventQueue();
      final lines = (await db.eventsOn(now)).map((e) => e.detail);
      expect(lines, contains("주인이 가르쳐 준 '돌아'를 처음으로 해냈다"));
    });

    test('배운 날에는 처음 배운 소리가 나고, 밤에는 짖지 않는다', () async {
      now = DateTime(2026, 9, 28, 23, 30);
      final c = await make(random: _Fixed(0));
      final cues = <Cue>[];
      c.cues.listen(cues.add);
      c.wake();
      for (var i = 0; i < 3; i++) {
        c.command(Trick.sit);
        c.tick(1);
        c.tick(1);
        c.tick(1);
        c.tick(1);
      }
      await pumpEventQueue();
      expect(cues, contains(Cue.chime));
      expect(cues, isNot(contains(Cue.bark)));
    });

    test('아직 못 배우는 개인기를 시키면 갸웃한다', () async {
      final c = await make();
      c.wake();
      expect(await c.talk('손!'), TalkOutcome.command);
      expect(c.bubble, '손? 그게 뭐야?');
      expect(c.tricks, isEmpty);
    });

    test('어제 연습한 개인기는 오늘 처음 볼 때 한 번 자랑한다', () async {
      await db.saveTrick(
        Trick.down,
        const TrickProgress(
          attempts: 4,
          successes: 3,
          days: 1,
          lastDay: '2026-09-27',
        ),
      );
      final c = await make();
      c.wake();
      await c.collected;
      expect(c.step.behavior, Behavior.lieBeside);
      expect(c.bubble, '봐! 연습했어!');
      await pumpEventQueue();
      c.wake();
      await c.collected;
      final shows = (await db.eventsOn(now)).where((e) => e.kind == 'show_off');
      expect(shows, hasLength(1));
    });
  });

  group('공놀이', () {
    void fetchOnce(PetController c) {
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      untilDrop(c);
    }

    test('물어 오면 기분이 오르고, 친밀도는 하루 몫까지만 오른다(앱을 다시 켜도)', () async {
      final c = await make();
      final before = c.stats.affection;
      c.wake();
      // 하루에 처음 보러 온 몫 1은 반김이 가져간다.
      expect(c.stats.affection, before + 1);
      c.takeOutBall();
      expect(c.ball, Ball.carried);
      c.arrived();
      expect(c.ball, Ball.ready);
      final start = c.stats;
      for (var i = 0; i < 10; i++) {
        fetchOnce(c);
        expect(c.ball, Ball.ready);
      }
      expect(c.stats.mood, greaterThan(start.mood));
      // 친함 단계의 하루 몫 5에서 처음 온 몫 1을 뺀 만큼만 오른다.
      final left = dailyBondFor(Intimacy.friend) - 1;
      expect(c.stats.affection, start.affection + left);
      expect(c.careScore, carePlay * left);
      await pumpEventQueue();
      final plays = (await db.eventsOn(now)).where((e) => e.kind == 'play');
      expect(plays, hasLength(1));

      final again = PetController(db, (await db.loadPet())!, clock: () => now);
      again.wake();
      again.takeOutBall();
      again.arrived();
      fetchOnce(again);
      expect(again.stats.affection, start.affection + left);

      now = DateTime(2026, 9, 29, 9);
      fetchOnce(again);
      expect(again.stats.affection, start.affection + left + 1);
    });

    test('자정 넘어 한 연습은 같은 날로 치고, 새벽 5시가 지나야 다음 날이다', () async {
      now = DateTime(2026, 9, 28, 23, 50);
      final c = await make(random: _Fixed(0));
      c.wake();
      c.command(Trick.sit);
      now = DateTime(2026, 9, 29, 0, 20);
      c.command(Trick.sit);
      expect(c.tricks[Trick.sit]?.days, 1);
      now = DateTime(2026, 9, 29, 9);
      c.command(Trick.sit);
      expect(c.tricks[Trick.sit]?.days, 2);
    });

    test('물고 오는 중에 쓰다듬으면 그 자리에 공을 내려놓고 칭찬은 없다', () async {
      final c = await make();
      c.wake();
      c.takeOutBall();
      c.arrived();
      expect(c.throwBall(), isTrue);
      c.ballLanded();
      c.arrived();
      expect(c.ball, Ball.carried);
      c.interact(Interaction.pet);
      expect(c.ball, Ball.ready);
      expect(c.careScore, carePet);
    });

    test('지쳤으면 공을 꺼내지 않고 쉰다', () async {
      final c = await make();
      c.wake();
      c.stats = c.stats.copyWith(energy: 10);
      c.takeOutBall();
      expect(c.ball, Ball.none);
      expect(c.step.behavior, Behavior.lieBeside);
    });

    test('밤에는 조금 기다리다 공을 치우고 잔다', () async {
      now = DateTime(2026, 9, 29, 1);
      final c = await make();
      c.wake();
      c.takeOutBall();
      c.arrived();
      expect(c.ball, Ball.ready);
      for (var i = 0; i < 40 && c.ball != Ball.none; i++) {
        c.tick(1);
      }
      expect(c.ball, Ball.none);
      // 제 자는 자리로 가서 잔다.
      for (var i = 0; i < 5 && c.step.behavior == Behavior.walk; i++) {
        c.arrived();
      }
      expect(c.step.behavior, Behavior.sleep);
      expect(c.petX, closeTo(c.sleepSpotX, sleepSpotSlack));
    });

    test('위기 말을 하면 공을 치우고 곁에만 있는다', () async {
      final c = await make();
      c.wake();
      c.takeOutBall();
      c.arrived();
      expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
      expect(c.ball, Ball.none);
    });

    test('한참 비웠다 열면 공은 치워져 있다', () async {
      final c = await make();
      c.wake();
      c.takeOutBall();
      c.arrived();
      c.sleepApp();
      now = now.add(const Duration(minutes: 30));
      c.wake();
      expect(c.ball, Ball.none);
    });

    test('그만 놀면 공을 치우고, 공이 없으면 던질 수 없다', () async {
      final c = await make();
      c.wake();
      c.takeOutBall();
      c.putBallAway();
      expect(c.ball, Ball.none);
      expect(c.throwBall(), isFalse);
    });
  });

  group('AI 없이 말 걸기', () {
    test('이름을 부르면 달려오고, 모르는 말엔 다가와 귀를 기울인다', () async {
      final c = await make(random: _Fixed(0));
      c.wake();
      c.step = const PetStep(Behavior.idle, 3);
      // 이름은 AI가 없어도 있어도 폰에서 바로 알아듣는 연습이다.
      expect(await c.talk('콩이야!'), TalkOutcome.command);
      expect(c.step.behavior, Behavior.run);
      expect(c.bubble, '응? 나 불렀어?');
      await c.talk('오늘 저녁 뭐 먹지');
      expect(c.bubble, '…?');
      await c.talk('놀자');
      expect(c.ball, Ball.carried);
    });

    test('산책 중에 놀자·잘 자 하면 길에서 놀거나 자지 않고 대답한다', () async {
      final c = await make();
      c.wake();
      expect(c.startWalk(), isTrue);
      await c.talk('놀자');
      expect(c.ball, Ball.none);
      expect(c.bubble, '집에 가서 놀자!');
      await c.talk('잘 자');
      expect(c.step.behavior, isNot(Behavior.sleep));
    });

    test('산책 중에 화면을 다시 켜면 집에 온 반김을 하지 않는다', () async {
      final c = await make();
      c.wake();
      expect(c.startWalk(), isTrue);
      c.sleepApp();
      now = now.add(const Duration(hours: 5));
      c.wake();
      expect(c.walking, isTrue);
      expect(c.step.behavior, isNot(Behavior.waitAtDoor));
      await pumpEventQueue();
      final greets = (await db.eventsOn(now)).where((e) => e.kind == 'greet');
      expect(greets, isEmpty);
    });

    test('설정에서 AI를 새로 연결하면 바로 다시 부른다', () async {
      final c = await make(
        respond: (_) => http.Response('{"error":{"message":"down"}}', 503),
      );
      c.wake();
      expect(await c.talk('안녕'), TalkOutcome.failed);
      final fresh = <http.Request>[];
      c.brain = AiBrain(
        baseUrl: 'https://new/v1',
        model: 'm',
        apiKey: 'k',
        client: MockClient((req) async {
          fresh.add(req);
          return ok(
            '{"mood_delta":1,"affection_delta":0,"action":"happy","thought":"응!","memory":null}',
          );
        }),
      );
      expect(await c.talk('다시 안녕'), TalkOutcome.ai);
      expect(fresh, hasLength(1));
    });

    test('앱을 새로 켜서 화면이 듣기 전에 난 반김 소리도 들린다', () async {
      final c = await make();
      await db.savePet(
        c.pet.copyWith(lastSeenAt: now.subtract(const Duration(hours: 1))),
      );
      final restarted = PetController(
        db,
        (await db.loadPet())!,
        clock: () => now,
      );
      restarted.wake();
      final cues = <Cue>[];
      restarted.cues.listen(cues.add);
      await pumpEventQueue();
      expect(cues, contains(Cue.yip));
    });

    test('AI와 말해서 오르는 친밀도도 하루 몫 안에서만 오르고, 속상해서 내려가는 건 그대로다', () async {
      var warmth = 2;
      final c = await make(
        respond: (_) => ok(
          '{"mood_delta":1,"affection_delta":$warmth,"action":"happy","thought":"좋아!","memory":null}',
        ),
      );
      final before = c.stats.affection;
      c.wake();
      for (final line in ['오늘 뭐 했어?', '너 최고야', '내일 또 보자']) {
        expect(await c.talk(line), TalkOutcome.ai);
      }
      // 처음 온 몫 1 + 첫 대화 4 = 친함 단계의 하루 몫 5. 그 뒤 대화로는 더 오르지 않는다.
      expect(c.stats.affection, before + dailyBondFor(Intimacy.friend));
      warmth = -1;
      await c.talk('저리 가');
      expect(c.stats.affection, before + dailyBondFor(Intimacy.friend) - 3);
    });

    test('친해질수록 하루 몫이 줄고(8→5→3), 보기만 해도 하루에 1은 오른다', () async {
      expect(dailyBondFor(Intimacy.stranger), 8);
      expect(dailyBondFor(Intimacy.friend), 5);
      expect(dailyBondFor(Intimacy.family), 3);
      final c = await make(affection: 80);
      final before = c.stats.affection;
      c.wake();
      expect(c.stats.affection, before + 1);
      // 가족은 하루 몫이 3이라 쓰다듬기 한 번(2)이면 그날 몫이 끝난다.
      c.interact(Interaction.pet);
      expect(c.stats.affection, before + 3);
      now = now.add(const Duration(minutes: 31));
      c.interact(Interaction.pet);
      expect(c.stats.affection, before + 3);
      // 다음 날 다시 켜기만 해도 1.
      now = DateTime(2026, 9, 29, 9);
      c.wake();
      expect(c.stats.affection, before + 4);
    });

    test('하루 처음 온 +1은 반김을 정한 뒤라 단계가 바뀌는 날도 반김 기준은 어제 단계대로다', () async {
      // 33은 낯가림(6시간 넘게 비워야 크게 반김), 34부터 친함(4시간).
      final c = await make(affection: 33);
      await db.savePet(
        c.pet.copyWith(lastSeenAt: now.subtract(const Duration(hours: 5))),
      );
      final again = PetController(db, (await db.loadPet())!, clock: () => now);
      expect(again.wake(), Greeting.hello);
      expect(again.stats.affection, 34);
    });

    test('시계를 하루 되돌렸다 돌아와도 +1과 하루 한도를 다시 주지 않는다', () async {
      final c = await make();
      final start = c.stats.affection;
      c.wake();
      expect(c.stats.affection, start + 1);
      now = now.subtract(const Duration(days: 1));
      c.wake();
      now = now.add(const Duration(days: 1));
      c.wake();
      expect(c.stats.affection, start + 1);
      // 다음 날은 정상으로 1.
      now = now.add(const Duration(days: 1));
      c.wake();
      expect(c.stats.affection, start + 2);
    });

    test('AI가 한 번 실패하면 10분 동안은 부르지 않는다', () async {
      final c = await make(
        respond: (_) => http.Response('{"error":{"message":"down"}}', 503),
      );
      c.wake();
      expect(await c.talk('안녕'), TalkOutcome.failed);
      expect(sent, hasLength(1));
      expect(await c.talk('안녕?'), TalkOutcome.failed);
      expect(sent, hasLength(1));
      now = now.add(const Duration(minutes: 11));
      await c.talk('안녕!');
      expect(sent, hasLength(2));
    });
  });

  test('쓰다듬기 연타로는 친밀도가 30분에 한 번만 오른다', () async {
    final c = await make();
    c.wake();
    final start = c.stats.affection;
    c.interact(Interaction.pet);
    expect(c.stats.affection, start + 2);
    now = now.add(const Duration(seconds: 5));
    c.interact(Interaction.pet);
    expect(c.stats.affection, start + 2);
    now = now.add(const Duration(minutes: 31));
    c.interact(Interaction.pet);
    expect(c.stats.affection, start + 4);
  });

  test('일기 미리 보기는 저장하지 않는다', () async {
    final c = await make(respond: (_) => ok('오늘은 공을 쫓았다.'));
    c.wake();
    c.interact(Interaction.feed);
    await pumpEventQueue();
    expect((await c.writeDiary(now, save: false))?.text, '오늘은 공을 쫓았다.');
    expect(await db.hasDiary(dayKey(now)), isFalse);
    expect(c.diaryVersion, 0);
  });
}
