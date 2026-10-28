import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/cuddle.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';

/// 작은 목소리(아이디어 #16): 힘없는 말엔 대답·개인기 대신 천천히 와서 말없이 옆에 앉는다.
void main() {
  group('지친 말 판정', () {
    test('낱말 안에서만 찾는다(띄어쓰기를 넘어 걸리지 않는다)', () {
      expect(needsComfort('오늘 너무 힘들었어'), isTrue);
      expect(needsComfort('너무힘들어'), isTrue);
      expect(needsComfort('기운 없어'), isTrue);
      expect(needsComfort('강아지 친구 만나러 카페 가자'), isFalse);
      expect(needsComfort('우리 강아지 쳐다보는 거 봐'), isFalse);
      expect(needsComfort('서울 고모 댁 다녀왔어'), isFalse);
      expect(needsComfort('겨울 고구마 맛있다'), isFalse);
    });

    test('펫에게 묻거나 아니라고 하거나 하지 말라는 말은 주인 얘기가 아니다', () {
      expect(askingOrDenying('혼자 있느라 외로웠지?'), isTrue);
      expect(askingOrDenying('기다리느라 힘들었지?'), isTrue);
      expect(askingOrDenying('하나도 안 힘들어'), isTrue);
      expect(askingOrDenying('슬프지 않아'), isTrue);
      expect(askingOrDenying('슬퍼하지 마'), isTrue);
      expect(askingOrDenying('오늘 너무 힘들었어'), isFalse);
    });

    test('폰 일기는 주인 말(따옴표)은 옮기지 않고 그 뒤 펫이 한 일은 남긴다', () {
      final diary = localDiary([
        (
          at: DateTime(2026, 10, 6, 20),
          kind: 'talk',
          detail: '주인이 "오늘 너무 지쳤어"라고 했다. 말없이 옆에 붙어 있었다',
        ),
      ], Random(1))!;
      expect(diary, contains('주인이 말을 걸어 줬다. 말없이 옆에 붙어 있었다'));
      expect(diary, isNot(contains('지쳤어')));
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

    /// [thought]·[action]을 답하는 가짜 AI. null이면 AI 없음, [fail]이면 AI가 오류를 낸다.
    Future<PetController> make({
      String? thought,
      String action = 'play',
      bool fail = false,
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
        quirk: const Value('sitBeforeEat'),
        pawMarks: const Value('hidden'),
      );
      await db.savePet(pet);
      final brain = thought == null && !fail
          ? null
          : AiBrain(
              baseUrl: 'https://pc/v1',
              model: 'm',
              apiKey: 'k',
              client: MockClient(
                (_) async => fail
                    ? http.Response('', 500)
                    : http.Response.bytes(
                        utf8.encode(
                          jsonEncode({
                            'choices': [
                              {
                                'message': {
                                  'content': jsonEncode({
                                    'mood_delta': 1,
                                    'affection_delta': 1,
                                    'action': action,
                                    'thought': thought,
                                    'memory': '주인이 회사에서 힘들었다',
                                  }),
                                },
                              },
                            ],
                          }),
                        ),
                        200,
                        headers: {
                          'content-type': 'application/json; charset=utf-8',
                        },
                      ),
              ),
            );
      final c = PetController(
        db,
        pet,
        systemPrompt: 'sys',
        diaryPrompt: 'diary',
        brain: brain,
        random: Random(1),
        clock: () => now,
      );
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

    test('AI가 없어도 힘없는 말엔 천천히 와서 말없이 옆에 앉는다', () async {
      final c = await make();
      await c.talk('오늘 너무 힘들었어');
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, rugX);
      expect(c.bubble, isNull);
      c.arrived();
      expect(c.step.behavior, Behavior.sit);
      expect(c.step.thought, isNull);
      expect(quietSteps.every((s) => s.thought == null), isTrue);
      await pumpEventQueue(times: 20);
      expect(await events('talk'), ['주인 목소리가 작았다. 말없이 옆에 붙어 있었다']);
    });

    test('AI가 있으면 기억은 남기되, 보이는 반응은 대답 대신 말없이 곁에("…"도 거둔다)', () async {
      final c = await make(thought: '힘내! 공 던져 줘!', action: 'play');
      await c.talk('오늘 너무 지쳤어');
      expect(c.bubble, isNull);
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, rugX);
      await pumpEventQueue(times: 20);
      expect(
        (await db.recentMemories(5)).map((m) => m.content),
        contains('주인이 회사에서 힘들었다'),
      );
      expect((await events('talk')).single, endsWith('말없이 옆에 붙어 있었다'));
    });

    test('기운이 없어도 힘없는 말엔 "졸려"라고 하지 않고 말없이 곁에', () async {
      final c = await make(thought: '놀자!', action: 'play');
      c.stats = c.stats.copyWith(energy: 10);
      await c.talk('오늘 너무 지쳤어');
      expect(c.bubble, isNull);
      expect(c.step.targetX, rugX);
    });

    test('AI가 실패해도 힘없는 말엔 말없이 곁에', () async {
      final c = await make(fail: true);
      await c.talk('오늘 너무 지쳤어');
      expect(c.bubble, isNull);
      expect(c.step.behavior, Behavior.walk);
      expect(c.step.targetX, rugX);
    });

    test('산책 중엔 걸음은 그대로 두고 말만 거둔다', () async {
      final c = await make();
      c.startWalk();
      await c.talk('오늘 너무 지쳤어');
      expect(c.walking, isTrue);
      expect(c.bubble, isNull);
      expect(c.step.targetX, isNot(rugX));
      await pumpEventQueue(times: 20);
      expect(await events('talk'), ['주인 목소리가 작았다. 말없이 같이 걸었다']);
    });

    test('위기 문장이 섞이면 상담 안내가 먼저다', () async {
      final c = await make();
      expect(await c.talk('너무 힘들어서 죽고 싶어'), TalkOutcome.crisis);
    });

    test('펫에게 묻는 말("외로웠지?")엔 평소처럼 대답하고 위로 선물도 잡지 않는다', () async {
      final c = await make(thought: '응! 보고 싶었어', action: 'happy');
      await c.talk('혼자 있느라 외로웠지?');
      expect(c.bubble, '응! 보고 싶었어');
      expect(c.pet.comfortDue, isFalse);
    });

    test('보통 말엔 AI 대답이 그대로 보인다', () async {
      final c = await make(thought: '꼬리가 저절로 흔들려', action: 'happy');
      await c.talk('오늘 날씨 좋다');
      expect(c.bubble, '꼬리가 저절로 흔들려');
    });
  });
}
