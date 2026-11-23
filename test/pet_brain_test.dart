import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

String answer(Map<String, Object?> decision) => jsonEncode({
  'choices': [
    {
      'message': {'content': jsonEncode(decision)},
    },
  ],
});

http.Response respond(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const comfort = {
  'mood_delta': -1,
  'affection_delta': 2,
  'action': 'lie_beside',
  'thought': '주인이 슬퍼 보여. 옆에 있어 줄게.',
  'memory': '주인이 회사에서 힘들었다.',
};

Future<Pet> makePet(AppDatabase db, DateTime at) => db.createPet(
  name: '콩이',
  stage: PetStage.puppy,
  furMain: 0xFFF8F1E6,
  furSecond: 0xFFFFFDF8,
  marking: 0xFF914F28,
  now: at,
);

void main() {
  group('parseDecision', () {
    test('정상 답을 읽고, 코드 블록으로 감싸도 읽는다', () {
      final d = parseDecision('```json\n${jsonEncode(comfort)}\n```')!;
      expect(d.action, PetAction.lieBeside);
      expect(d.affectionDelta, 2);
      expect(d.memory, '주인이 회사에서 힘들었다.');
    });

    test('목록 밖 행동, 범위 밖 변화량, 빈 속마음은 버린다', () {
      expect(parseDecision(jsonEncode({...comfort, 'action': 'fly'})), isNull);
      expect(parseDecision(jsonEncode({...comfort, 'mood_delta': 5})), isNull);
      expect(parseDecision(jsonEncode({...comfort, 'thought': '  '})), isNull);
      expect(parseDecision('그냥 문장'), isNull);
    });

    test('긴 속마음은 40자로 자르고, 빈 기억은 null로 본다', () {
      final d = parseDecision(
        jsonEncode({...comfort, 'thought': '가' * 60, 'memory': ' '}),
      )!;
      expect(d.thought.length, maxThought);
      expect(d.memory, isNull);
    });
  });

  test('위기 표현은 띄어쓰기와 어미가 달라도 잡고, 평범한 말은 잡지 않는다', () {
    for (final t in [
      '요즘 그냥 죽고싶어',
      '살기 싫다',
      '살고 싶지 않아',
      '살기가 싫어',
      '죽어버리고 싶어',
      '극단적인 선택을 할까 봐',
    ]) {
      expect(isCrisis(t), isTrue, reason: t);
    }
    for (final t in ['배고파 죽겠다', '오늘 힘들었어', '자살골 넣었어', '피곤해 죽겠다']) {
      expect(isCrisis(t), isFalse, reason: t);
    }
    // 안전한 쪽으로 두는 오탐. 상담 안내가 한 번 더 뜨는 정도라 감수한다.
    expect(isCrisis('혼자 살기 싫어'), isTrue);
  });

  test('이모지가 자르는 자리에 걸려도 글자가 깨지지 않는다', () {
    final d = parseDecision(
      jsonEncode({...comfort, 'thought': '${'가' * 39}🐶나'}),
    )!;
    expect(d.thought, '${'가' * 39}…');
    expect(d.thought.runes.length, maxThought);
  });

  test('200인데 형식이 이상한 답도 BrainError로 바뀐다', () async {
    for (final body in [
      '<html>gateway</html>',
      '{"choices":[]}',
      '{"choices":[{"message":{"content":"not json"}}]}',
    ]) {
      final brain = AiBrain(
        baseUrl: 'https://x/v1',
        model: 'm',
        apiKey: 'k',
        client: MockClient((_) async => respond(body, 200)),
      );
      await expectLater(
        () => brain.decide('s', 'u'),
        throwsA(isA<BrainError>()),
        reason: body,
      );
    }
  });

  test('유저 턴에 상태·기억·입력이 평가셋과 같은 형식으로 들어간다', () {
    final turn = userTurn(
      const PetStats(mood: 60.4, hunger: 35, energy: 70, affection: 40),
      ['어제 야근했다.'],
      '나 왔어',
    );
    expect(
      turn,
      '상태: {"mood":60,"hunger":35,"energy":70,"affection":40}\n기억: - 어제 야근했다.\n주인: "나 왔어"',
    );
  });

  test('AiBrain은 API 오류를 메시지와 함께 BrainError로 바꾼다', () async {
    final brain = AiBrain(
      baseUrl: 'https://x/v1',
      model: 'm',
      apiKey: 'bad',
      client: MockClient(
        (_) async => respond('{"error":{"message":"Invalid API Key"}}', 401),
      ),
    );
    expect(
      () => brain.decide('s', 'u'),
      throwsA(
        isA<BrainError>().having(
          (e) => e.message,
          'message',
          contains('Invalid API Key'),
        ),
      ),
    );
  });

  group('말 걸기', () {
    late AppDatabase db;
    final now = DateTime(2026, 9, 25, 14);
    late List<http.Request> sent;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      sent = [];
    });
    // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> make({
      Duration away = Duration.zero,
      http.Response? reply,
    }) async {
      final pet = await makePet(db, now.subtract(away));
      final brain = reply == null
          ? null
          : AiBrain(
              baseUrl: 'https://pc.example/v1/',
              model: 'gemma3n:e4b',
              apiKey: 'k',
              client: MockClient((req) async {
                sent.add(req);
                return reply;
              }),
            );
      return PetController(
        db,
        pet,
        systemPrompt: 'sys',
        brain: brain,
        random: Random(1),
        clock: () => now,
      );
    }

    test(
      '힘없는 말엔 AI 답대로 변화량×3과 기억을 남기되, 속마음 없이 천천히 와서 옆에 앉는다(작은 목소리)',
      () async {
        final c = await make(reply: respond(answer(comfort), 200));
        c.wake();
        final before = c.stats;
        final outcome = await c.talk('오늘 회사에서 너무 힘들었어');
        expect(outcome, TalkOutcome.ai);
        expect(c.step.behavior, Behavior.walk);
        c.arrived();
        expect(c.step.behavior, Behavior.sit);
        expect(c.bubble, isNull);
        expect(c.stats.mood, before.mood - 3);
        expect(c.stats.affection, before.affection + 6);
        expect((await db.recentMemories(5)).map((m) => m.content), [
          '주인이 회사에서 힘들었다.',
        ]);
      },
    );

    test('설정한 주소·모델·키로 요청한다(끝의 / 는 무시)', () async {
      final c = await make(reply: respond(answer(comfort), 200));
      c.wake();
      await c.talk('안녕');
      final req = sent.single;
      expect(req.url.toString(), 'https://pc.example/v1/chat/completions');
      expect(req.headers['Authorization'], 'Bearer k');
      expect(
        (jsonDecode(req.body) as Map<String, dynamic>)['model'],
        'gemma3n:e4b',
      );
    });

    test('다음 대화에는 저장된 기억이 함께 간다', () async {
      final c = await make(reply: respond(answer(comfort), 200));
      c.wake();
      await c.talk('오늘 회사에서 너무 힘들었어');
      await c.talk('나 왔어');
      final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(
        (body['messages'] as List).last['content'],
        contains('- (오늘) 주인이 회사에서 힘들었다.'),
      );
    });

    test('고정한 옛 기억이 다음 대화에 들어가고 지운 기억은 다음 요청에서 빠진다', () async {
      final c = await make(
        reply: respond(answer({...comfort, 'memory': null}), 200),
      );
      for (var i = 1; i <= 7; i++) {
        await db.addMemory('산책길$i', now.subtract(Duration(days: 8 - i)));
      }
      final oldest = (await db.recentMemories(7)).last;
      expect(await c.setMemoryPinned(oldest.id, true), MemoryPinResult.saved);
      c.wake();
      Future<String> prompt() async {
        await c.talk('나 왔어');
        final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
        return (body['messages'] as List).last['content'] as String;
      }

      final withPin = await prompt();
      expect(withPin, contains('산책길1'));
      expect(withPin, contains('산책길7'));
      expect(withPin, isNot(contains('산책길2')));
      expect(withPin, isNot(contains('산책길3')));
      await c.forgetMemory(oldest.id);
      final after = await prompt();
      expect(after, isNot(contains('산책길1')));
      expect(after, contains('산책길3'));
    });

    test('기운이 바닥이면 AI가 놀자고 해도 옆에 엎드린다', () async {
      final c = await make(
        reply: respond(
          answer({...comfort, 'action': 'play', 'mood_delta': 2}),
          200,
        ),
      );
      c.wake();
      c.stats = c.stats.copyWith(energy: 10);
      final mood = c.stats.mood;
      await c.talk('놀자!');
      expect(c.step.behavior, Behavior.lieBeside);
      expect(c.bubble, '졸려… 조금만 쉴래.');
      expect(c.stats.mood, mood);
    });

    test('AI가 실패하면 폰 안 반응으로 다가오고 오류를 남긴다', () async {
      final c = await make(
        reply: respond('{"error":{"message":"rate limit"}}', 429),
      );
      c.wake();
      expect(await c.talk('안녕'), TalkOutcome.failed);
      expect(c.step.behavior, Behavior.run);
      expect(c.bubble, isNotNull);
      expect(c.lastError, contains('429'));
    });

    test('키가 없으면 AI를 부르지 않고 폰 안 반응만 한다', () async {
      final c = await make();
      c.wake();
      expect(await c.talk('안녕'), TalkOutcome.noBrain);
      expect(c.bubble, isNotNull);
    });

    test('위기 표현은 AI에 보내지 않는다', () async {
      final c = await make(reply: respond(answer(comfort), 200));
      c.wake();
      expect(await c.talk('다 그만두고 죽고 싶어'), TalkOutcome.crisis);
      expect(sent, isEmpty);
      expect(await db.recentMemories(5), isEmpty);
    });

    test('오래 비웠다 돌아오면 비운 시간을 담아 반김 속마음을 받는다', () async {
      final c = await make(
        away: const Duration(hours: 6),
        reply: respond(answer(comfort), 200),
      );
      c.wake();
      await pumpEventQueue();
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect((body['messages'] as List).last['content'], contains('6시간 만에'));
      expect(c.step.behavior, Behavior.waitAtDoor);
      expect(c.bubble, comfort['thought']);
    });

    test('하루 대화 한도를 넘으면 AI를 부르지 않는다', () async {
      final c = await make(
        reply: respond(answer({...comfort, 'memory': null}), 200),
      );
      c.wake();
      for (var i = 0; i < PetController.dailyTalkLimit; i++) {
        await c.talk('안녕 $i');
      }
      expect(await c.talk('한 번 더'), TalkOutcome.limited);
      expect(sent.length, PetController.dailyTalkLimit);
    });
  });
}
