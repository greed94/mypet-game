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
import 'package:mypet/services/weather.dart';

http.Response reply(Map<String, Object?> body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> chat(String content) => {
  'choices': [
    {
      'message': {'content': content},
    },
  ],
};

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 9, 25, 14);
  late List<http.Request> sent;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 25, 14);
    sent = [];
  });
  // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> make({
    DateTime? bornAt,
    PetStage stage = PetStage.puppy,
    double careScore = 0,
    Duration away = Duration.zero,
    String Function(http.Request)? answer,
    WeatherService? weather,
    bool withRegion = false,
  }) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: stage,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: bornAt ?? now,
      latitude: withRegion ? 37.5 : null,
      longitude: withRegion ? 127.0 : null,
    );
    pet = pet.copyWith(careScore: careScore, lastSeenAt: now.subtract(away));
    await db.savePet(pet);
    final brain = answer == null
        ? null
        : AiBrain(
            baseUrl: 'https://pc/v1',
            model: 'm',
            apiKey: 'k',
            client: MockClient((req) async {
              sent.add(req);
              return reply(chat(answer(req)));
            }),
          );
    return PetController(
      db,
      pet,
      systemPrompt: 'sys',
      diaryPrompt: 'diary',
      brain: brain,
      weatherService: weather,
      random: Random(1),
      clock: () => now,
    );
  }

  test('밥·공놀이·쓰다듬기가 돌봄 점수와 그날의 일로 남는다', () async {
    final c = await make();
    c.wake();
    c.interact(Interaction.feed);
    c.interact(Interaction.pet);
    c.takeOutBall();
    c.arrived(); // 공을 물고 가운데까지 왔다
    expect(c.ball, Ball.ready);
    expect(c.throwBall(), isTrue);
    c.ballLanded();
    c.arrived(); // 공에 닿아 물었다
    expect(c.ball, Ball.carried);
    c.tick(1);
    c.arrived(); // 주인 앞까지 물어 왔다
    expect(c.ball, Ball.ready);
    expect(c.careScore, careFeed + carePlay + carePet);
    await pumpEventQueue();
    final kinds = (await db.eventsOn(now)).map((e) => e.kind).toList();
    expect(kinds, containsAll(['feed', 'play', 'pet']));
    expect((await db.loadPet())!.careScore, c.careScore);
  });

  test('산책은 시작·걸음·끝이 이어지고 끝나면 보상과 기록이 남는다', () async {
    final c = await make();
    c.wake();
    expect(c.startWalk(), isTrue);
    expect(c.walking, isTrue);
    expect(c.step.behavior, Behavior.walk);
    c.updateWalkSteps(1200);
    now = now.add(const Duration(minutes: 20));
    final r = c.endWalk();
    expect(r.steps, 1200);
    expect(r.minutes, 20);
    expect(c.walking, isFalse);
    expect(c.careScore, closeTo(careWalkBase + 1200 / 500, 0.001));
    await pumpEventQueue();
    final walk = (await db.eventsOn(now)).where((e) => e.kind == 'walk').single;
    expect(walk.detail, contains('20분'));
    expect(walk.detail, contains('1200걸음'));
  });

  test('지친 펫은 산책을 거절한다', () async {
    final c = await make();
    c.wake();
    c.stats = c.stats.copyWith(energy: 5);
    expect(c.startWalk(), isFalse);
    expect(c.walking, isFalse);
  });

  test('2주 넘게 잘 돌본 아기는 켤 때 어른이 되고 그림 버전이 올라간다', () async {
    final c = await make(
      bornAt: now.subtract(const Duration(days: 15)),
      careScore: 70,
    );
    expect(c.spriteVersion, 0);
    c.wake();
    expect(c.pet.stage, PetStage.adult);
    expect(c.spriteVersion, 1);
    await pumpEventQueue();
    expect((await db.loadPet())!.stage, PetStage.adult);
    expect((await db.eventsOn(now)).map((e) => e.kind), contains('grow'));
  });

  test('AI가 산책 가자고 하면 제안 표시가 켜지고, 기억에는 며칠 전인지 붙는다', () async {
    await db.addMemory('주인이 야근했다.', now.subtract(const Duration(days: 1)));
    final c = await make(
      answer: (_) => jsonEncode({
        'mood_delta': 2,
        'affection_delta': 1,
        'action': 'propose_walk',
        'thought': '산책 가자!',
        'memory': null,
      }),
    );
    c.wake();
    expect(await c.talk('심심하다'), TalkOutcome.ai);
    expect(c.walkProposed, isTrue);
    final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
    expect(
      (body['messages'] as List).last['content'],
      contains('(어제) 주인이 야근했다.'),
    );
    c.startWalk();
    expect(c.walkProposed, isFalse);
  });

  test('일기는 그날의 일로 쓰고 저장하며, 일이 없으면 쓰지 않는다', () async {
    final c = await make(
      answer: (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body.containsKey('response_format'), isFalse);
        expect(
          (body['messages'] as List).last['content'],
          contains('주인이 밥을 줬다'),
        );
        return '아침에 밥 냄새에 눈이 떠졌다. 주인이 옆에 있어서 좋았다.';
      },
    );
    c.wake();
    expect(await c.writeDiary(now), isNull);
    expect(c.lastError, contains('있었던 일이 없어요'));

    c.interact(Interaction.feed);
    await pumpEventQueue();
    final diary = await c.writeDiary(now);
    expect(diary?.text, contains('밥 냄새'));
    expect(diary?.byAi, isTrue);
    expect(c.diaryVersion, 1);
    final diaries = await db.allDiaries();
    expect(diaries.single.day, '2026-09-25');
  });

  test('자정 넘어 한 일은 새벽 5시 전까지 그날 일기에 들어간다', () async {
    now = DateTime(2026, 9, 26, 0, 30);
    await db.addEvent('feed', '주인이 밥을 줬다', DateTime(2026, 9, 25, 22));
    await db.addEvent('pet', '주인이 쓰다듬어 줬다', now);
    await db.addEvent('walk', '아침 산책', DateTime(2026, 9, 26, 6));
    final events = await db.eventsOn(now);
    expect(events.map((e) => e.kind), ['feed', 'pet']);
  });

  test('하루가 바뀌어 처음 켜면 어제 일기를 알아서 쓴다', () async {
    final yesterday = now.subtract(const Duration(days: 1));
    await db.addEvent('feed', '주인이 밥을 줬다', yesterday);
    final c = await make(answer: (_) => '어제는 밥을 먹고 잘 잤다.');
    c.wake();
    await pumpEventQueue();
    expect(await db.hasDiary(dayKey(yesterday)), isTrue);
  });

  test('동네가 있으면 켤 때 날씨를 받아 행동과 기록에 쓴다', () async {
    final weather = WeatherService(
      client: MockClient(
        (_) async => reply({
          'current': {'temperature_2m': 12.0, 'weather_code': 63},
        }),
      ),
    );
    final c = await make(weather: weather, withRegion: true);
    c.wake();
    await pumpEventQueue();
    expect(c.weather?.sky, Sky.rain);
    expect(c.weatherMood, WeatherMood.watchWindow);
    expect(
      (await db.eventsOn(now)).where((e) => e.kind == 'weather').single.detail,
      contains('비 12도'),
    );
  });
}
