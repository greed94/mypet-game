import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

const _walk = PetDecision(
  moodDelta: 2,
  affectionDelta: 1,
  action: PetAction.proposeWalk,
  thought: '바깥 공기 맡으러 갈까?',
  memory: '주인은 노란 공을 좋아한다.',
);
const _sit = PetDecision(
  moodDelta: 0,
  affectionDelta: 0,
  action: PetAction.sit,
  thought: '여기 앉을게.',
);

class _Turn {
  final started = Completer<void>();
  final answer = Completer<PetDecision>();
}

class _DelayedBrain implements PetBrain {
  _DelayedBrain(int count) : turns = List.generate(count, (_) => _Turn());
  final List<_Turn> turns;
  int sent = 0;
  @override
  String get label => '합성 대화';
  @override
  Future<PetDecision> decide(String system, String user) {
    final turn = turns[sent++];
    turn.started.complete();
    return turn.answer.future;
  }

  @override
  Future<String> writeText(String system, String user) async => '합성 일기';
}

void main() {
  late AppDatabase db;
  late PetController c;
  late _DelayedBrain brain;
  late DateTime now;
  Future<void> open(int count, {DateTime? at}) async {
    db = AppDatabase(NativeDatabase.memory());
    now = at ?? DateTime(2026, 11, 24, 14);
    final pet = await db.createPet(
      name: '보리',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    brain = _DelayedBrain(count);
    c = PetController(
      db,
      pet,
      clock: () => now,
      random: Random(8),
      brain: brain,
    );
    c.wake();
    await c.settled;
    c.stats = c.stats.copyWith(hunger: 65, energy: 80);
    addTearDown(() async {
      for (final turn in brain.turns) {
        if (!turn.answer.isCompleted) turn.answer.complete(_sit);
      }
      await c.settled;
      c.dispose();
      await db.close();
    });
  }

  test('밥을 준 뒤 도착한 답은 식사를 이어가고 대화한 시각의 기억만 남긴다', () async {
    await open(1);
    final heard = now;
    final talking = c.talk('뜰에서 노란 공을 찾았어');
    await brain.turns.first.started.future;
    now = now.add(const Duration(minutes: 1));
    c.interact(Interaction.feed);
    final meal = c.step;
    final mood = c.stats.mood;
    brain.turns.first.answer.complete(_walk);
    expect(await talking, TalkOutcome.ignored);
    expect(c.step, same(meal));
    expect(c.bubble, isNot('…'));
    expect(c.bubble, isNot(_walk.thought));
    expect(c.walkProposed, isFalse);
    expect(c.stats.mood, mood);
    expect(c.pet.talksToday, 1);
    final remembered = (await db.recentMemories(1)).single;
    expect(remembered.content, _walk.memory);
    expect(remembered.createdAt, heard);
    await c.settled;
    final events = await db.eventsOn(heard);
    expect(events.where((e) => e.kind == 'feed'), hasLength(1));
    expect(
      events.where((e) => e.kind == 'talk').single.detail,
      isNot(contains('산책')),
    );
  });

  test('그만 놀기를 누른 뒤 늦은 대화 오류가 공놀이를 다시 열지 않는다', () async {
    await open(1);
    c.takeOutBall();
    c.arrived();
    expect(c.ball, Ball.ready);
    final talking = c.talk('놀자');
    await brain.turns.first.started.future;
    c.putBallAway();
    expect(c.ball, Ball.none);
    brain.turns.first.answer.completeError(
      BrainError('합성 지연 오류', kind: BrainErrorKind.network),
    );
    final result = await talking;
    expect(c.ball, Ball.none);
    expect(result, TalkOutcome.ignored);
  });

  test('나중 질문이 먼저 답을 받으면 이전 연결 오류가 새 반응과 다음 연결을 덮지 않는다', () async {
    await open(3);
    final previousStatus = c.lastError;
    final earlier = c.talk('뜨락에 무슨 소리가 났을까');
    await brain.turns[0].started.future;
    final later = c.talk('새 방석은 보들보들하네');
    await brain.turns[1].started.future;
    brain.turns[1].answer.complete(_sit);
    expect(await later, TalkOutcome.ai);
    brain.turns[0].answer.completeError(
      BrainError('합성 지연 오류', kind: BrainErrorKind.network),
    );
    expect(await earlier, TalkOutcome.ignored);
    expect(c.bubble, _sit.thought);
    expect(c.lastError, previousStatus);
    final next = c.talk('창밖 풍경이 예쁘네');
    await brain.turns[2].started.future;
    brain.turns[2].answer.complete(_sit);
    expect(await next, TalkOutcome.ai);
  });

  for (final fails in [true, false]) {
    test('AI를 바꾼 뒤 이전 제공자의 성공·실패가 새 연결에 들어오지 않는다 (오류 $fails)', () async {
      await open(1);
      final previousStatus = c.lastError;
      final talking = c.talk('저 멀리 뭐가 보이니');
      await brain.turns.first.started.future;
      final replacement = _DelayedBrain(1);
      c.brain = replacement;
      if (fails) {
        brain.turns.first.answer.completeError(
          BrainError('이전 제공자', kind: BrainErrorKind.network),
        );
      } else {
        brain.turns.first.answer.complete(_walk);
      }
      expect(await talking, TalkOutcome.ignored);
      expect(c.lastError, previousStatus);
      expect(await db.recentMemories(1), isEmpty);
      final fresh = c.talk('정원에 낙엽이 쌓였어');
      await replacement.turns.first.started.future;
      replacement.turns.first.answer.complete(_sit);
      expect(await fresh, TalkOutcome.ai);
    });
  }

  for (final mutation in [
    'INSERT ON events',
    'UPDATE ON events',
    'INSERT ON memories',
  ]) {
    test('기록 쓰기 실패 중에도 펫은 대답하고 다음 말을 받을 수 있다 ($mutation)', () async {
      await open(2);
      await db.customStatement(
        "CREATE TRIGGER fail_talk BEFORE $mutation BEGIN SELECT RAISE(ABORT, 'synthetic storage error'); END",
      );
      brain.turns.first.answer.complete(_walk);
      final result = await c.talk('새 방석은 어디에 둘까');
      expect(c.bubble, _walk.thought);
      expect(result, TalkOutcome.recordIssue);
      expect(c.pet.talksToday, 1);
      await db.customStatement('DROP TRIGGER fail_talk');
      brain.turns.last.answer.complete(_sit);
      expect(await c.talk('창문에 햇빛이 들어오네'), TalkOutcome.ai);
      expect(brain.sent, 2);
    });
  }

  Future<void> useAllButOne() async {
    await open(PetController.dailyTalkLimit);
    for (var i = 0; i < PetController.dailyTalkLimit - 1; i++) {
      brain.turns[i].answer.complete(_sit);
      expect(await c.talk('방석 이야기 $i'), TalkOutcome.ai);
    }
  }

  test('남은 대화 한 자리에 두 요청이 겹쳐도 AI 호출은 한 번만 늘어난다', () async {
    await useAllButOne();
    final requests = [c.talk('빈 방석을 발견했어'), c.talk('우리 창가에 볕이 좋아')];
    await brain.turns.last.started.future;
    brain.turns.last.answer.complete(_sit);
    await Future.wait(requests);
    expect(brain.sent, PetController.dailyTalkLimit);
    expect(c.pet.talksToday, PetController.dailyTalkLimit);
  });

  test('저장한 기억을 읽지 못하면 로컬로 응답하고 읽기가 회복되면 다음 말을 AI에 보낸다', () async {
    await useAllButOne();
    final used = PetController.dailyTalkLimit - 1;
    await db.customStatement('ALTER TABLE memories RENAME TO missing_memories');
    expect(await c.talk('창밖이 조용하네'), TalkOutcome.historyUnavailable);
    expect(c.bubble, isNot('…'));
    expect(brain.sent, used);
    expect(c.pet.talksToday, used);
    await db.customStatement('ALTER TABLE missing_memories RENAME TO memories');
    brain.turns.last.answer.complete(_sit);
    expect(await c.talk('볕 드는 방석을 찾았어'), TalkOutcome.ai);
  });

  test('화면을 끈 뒤 도착한 성공은 실제 마지막 방문 시각을 밀지 않는다', () async {
    await open(1);
    final talking = c.talk('새 방석은 어떤 느낌일까');
    await brain.turns.first.started.future;
    now = now.add(const Duration(seconds: 2));
    final left = now;
    c.sleepApp();
    now = now.add(const Duration(seconds: 10));
    brain.turns.first.answer.complete(_walk);
    expect(await talking, TalkOutcome.ignored);
    await c.settled;
    expect((await db.loadPet())!.lastSeenAt, left);
    expect((await db.recentMemories(1)).single.content, _walk.memory);
  });

  test('지쳐서 외출을 거절한 뒤에는 대기하던 AI가 산책을 제안하지 않는다', () async {
    await open(1);
    final talking = c.talk('창밖 새를 구경할까');
    await brain.turns.first.started.future;
    c.stats = c.stats.copyWith(energy: 5);
    expect(c.canGoOut(), isFalse);
    final refusal = c.bubble;
    brain.turns.first.answer.complete(_walk);
    expect(await talking, TalkOutcome.ignored);
    expect(c.bubble, refusal);
    expect(c.walkProposed, isFalse);
  });

  test('같은 초에 보낸 두 기억은 응답이 뒤집혀도 나중 발화가 대화의 마지막 자리를 쓴다', () async {
    await open(2);
    for (var n = 0; n < 4; n++) {
      await db.addMemory('고정 항목 $n', now.subtract(const Duration(days: 1)));
      final latest = (await db.recentMemories(1)).single;
      await db.setMemoryPinned(latest.id, true);
    }
    final earlier = c.talk('빨간 공이 여기 있어');
    await brain.turns.first.started.future;
    final later = c.talk('이번에는 초록 공이네');
    await brain.turns.last.started.future;
    const latestMemory = '초록 공이 이번에 생겼다.';
    brain.turns.last.answer.complete(
      const PetDecision(
        moodDelta: 0,
        affectionDelta: 0,
        action: PetAction.sit,
        thought: '킁킁.',
        memory: latestMemory,
      ),
    );
    expect(await later, TalkOutcome.ai);
    brain.turns.first.answer.complete(_walk);
    expect(await earlier, TalkOutcome.ignored);
    expect((await db.conversationMemories()).last.content, latestMemory);
    expect((await db.recentMemories(2)).first.content, latestMemory);
  });

  test('05시 전 보낸 대화는 답을 기다리는 중에도 다음 날의 일기 재료로 한 번 남는다', () async {
    final heard = DateTime(2026, 11, 24, 4, 59, 59);
    await open(1, at: heard);
    final talking = c.talk('창밖이 아직 깜깜해');
    await brain.turns.first.started.future;
    expect(
      (await db.eventsOn(heard)).where((e) => e.kind == 'talk'),
      hasLength(1),
    );
    c.sleepApp();
    now = heard.add(const Duration(seconds: 3));
    c.wake();
    brain.turns.first.answer.complete(_walk);
    await talking;
    await c.settled;
    expect((await db.allDiaries()).single.day, dayKey(petDate(heard)));
    expect(
      (await db.eventsOn(heard)).where((e) => e.kind == 'talk'),
      hasLength(1),
    );
    expect((await db.eventsOn(now)).where((e) => e.kind == 'talk'), isEmpty);
  });

  test('대화 도중 유치원에 맡긴 펫은 오래된 답이 도착해도 등원 행동을 이어간다', () async {
    await open(1);
    final talking = c.talk('우리 집에서 누가 제일 용감할까');
    await brain.turns.first.started.future;
    expect(c.goToKindergarten(), isTrue);
    expect(c.dropOff(), isTrue);
    final arrival = c.step;
    final greeting = c.bubble;
    brain.turns.first.answer.complete(_walk);
    expect(await talking, TalkOutcome.ignored);
    expect(c.inDaycare, isTrue);
    expect(c.step, same(arrival));
    expect(c.bubble, greeting);
  });
}
