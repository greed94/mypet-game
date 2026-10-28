import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/homecam.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/services/test_mode.dart';

/// 2026-10-02 교차 리뷰에서 나온 것들. 기능끼리 겹치는 자리라 한 파일에 모았다.
void main() {
  late AppDatabase db;
  var now = DateTime(2026, 10, 5, 9);
  var steps = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 5, 9);
    steps = 1000;
  });
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<Pet> seed({Duration away = Duration.zero}) async {
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
      lastStepTotal: const Value(1000),
      pocketDay: const Value(null),
      activity: const Value(0.4),
      attachment: const Value(0.8),
    );
    await db.savePet(pet);
    return pet;
  }

  PetController open(Pet pet, {PetBrain? brain}) => PetController(
    db,
    pet,
    brain: brain,
    readStepTotal: () async => steps,
    random: Random(1),
    clock: () => now,
  );

  Future<PetController> reopen(PetController old, Duration later) async {
    old.sleepApp();
    await pumpEventQueue();
    now = now.add(later);
    final c = open((await db.loadPet())!);
    c.wake();
    await c.collected;
    return c;
  }

  test('유치원에 맡긴 동안 열면: 집에 혼자 있던 게 아니라 주머니 걸음 발견물도, 홈캠도 없다', () async {
    final c = open(await seed());
    c.wake();
    await c.collected;
    c.goToKindergarten();
    c.dropOff();
    steps = 9000; // 주인은 그동안 많이 걸었다.
    final later = await reopen(c, const Duration(hours: 5));
    expect(later.inDaycare, isTrue);
    expect(later.carried, isEmpty);
    expect(later.homeCam, isEmpty);
    expect((await db.loadPet())!.lastStepTotal, 9000);
  });

  test('하원 버스 뒤 혼자 있던 시간의 홈캠엔 "나간 문 앞" 장면이 없다', () async {
    final c = open(await seed());
    c.wake();
    await c.collected;
    c.goToKindergarten();
    c.dropOff();
    final later = await reopen(c, const Duration(hours: 13)); // 22시: 버스 뒤 3시간
    expect(later.inDaycare, isFalse);
    expect(later.homeCam, isNotEmpty);
    expect(later.homeCam.map((m) => m.kind), isNot(contains(CamKind.doorOut)));
  });

  test('안 본 홈캠은 잠깐 다른 앱에 다녀와도 남고, 끝까지 보면 사라진다', () async {
    now = DateTime(2026, 10, 5, 19);
    final c = open(await seed(away: const Duration(hours: 10)));
    c.wake();
    await c.collected;
    final cam = c.homeCam.length;
    expect(cam, greaterThan(0));
    // 잠깐 다른 앱: 같은 컨트롤러가 멈췄다 다시 깨어난다.
    c.sleepApp();
    now = now.add(const Duration(seconds: 20));
    c.wake();
    await c.collected;
    expect(c.homeCam.length, cam);
    c.startReplay();
    for (var i = 0; i < 40 && c.replaying; i++) {
      c.tick(1);
    }
    expect(c.replaying, isFalse);
    expect(c.homeCam, isEmpty);
  });

  test('CCTV 중 위기 문장: 안내는 그대로 뜨고, 화면 속 펫이 곁으로 오지는 않는다', () async {
    final c = open(await seed());
    c.wake();
    await c.collected;
    c.goToKindergarten();
    c.dropOff();
    c.step = const PetStep(Behavior.idle, 3);
    expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
    expect(c.bubble, isNot('곁에 있을게.'));
    expect(c.step.behavior, isNot(Behavior.lieBeside));
    expect((await db.loadPet())!.lastCrisisAt, isNotNull);
  });

  test('구경하던 유치원은 저녁 7시에 닫혀 집으로 온다', () async {
    now = DateTime(2026, 10, 5, 18, 59, 59);
    final c = open(await seed());
    c.wake();
    await c.collected;
    expect(c.goToKindergarten(), isTrue);
    c.tick(0.5);
    expect(c.spot, Spot.kindergarten);
    now = DateTime(2026, 10, 5, 19);
    c.tick(0.5);
    expect(c.spot, Spot.home);
    expect(c.bubble, '문 닫을 시간이래.');
  });

  test('AI 대답을 기다리는 동안엔 settled가 끝나지 않는다(연습 모드 전환이 닫힌 DB에 쓰지 않게)', () async {
    final gate = Completer<void>();
    final brain = AiBrain(
      baseUrl: 'https://pc.example/v1/',
      model: 'm',
      apiKey: 'k',
      client: MockClient((req) async {
        await gate.future;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'mood_delta': 1,
                      'affection_delta': 1,
                      'action': 'sit',
                      'thought': '응.',
                      'memory': null,
                    }),
                  },
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final c = open(await seed(), brain: brain);
    c.wake();
    await c.collected;
    var settled = false;
    final talking = c.talk('오늘 어땠어');
    unawaited(c.settled.then((_) => settled = true));
    await pumpEventQueue(times: 20);
    expect(settled, isFalse);
    gate.complete();
    await talking;
    await pumpEventQueue(times: 20);
    expect(settled, isTrue);
  });

  test('시간 보내기는 파일을 먼저 쓰고 한 번에 시계를 옮긴다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_cr_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/test_mode.json');
    final mode = TestMode(file, on: true);
    final base = DateTime(2026, 10, 5, 10);
    final c = PetController(
      db,
      await seed(),
      readStepTotal: () async => steps,
      random: Random(1),
      clock: () => base.add(mode.offset),
    );
    c.wake();
    await c.collected;
    await mode.jump(c, const Duration(hours: 3));
    expect(mode.offset, const Duration(hours: 3));
    expect((await TestMode.load(file)).offset, const Duration(hours: 3));
    expect(c.now(), DateTime(2026, 10, 5, 13));
  });
}
