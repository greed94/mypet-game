// 장면 미리보기: 폰에 설치하지 않고 게임 화면(방·카페·유치원·간식 가게·병원)을 테스트 안에서 그려
// shots/scene_<장소>.png로 남긴다. 폰 빌드를 못 할 때(PC 메모리, 연결 끊김) 그림이 깨지지 않았는지 보는 용도.
// 움직임·소리·실기기 글꼴 차이는 못 본다. 그건 실기기 몫.
//
// 실행: flutter test tools/scene_preview/scene_preview_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/pet_game.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/services/weather.dart';
import 'preview_fonts.dart';

const _key = ValueKey('scene');

void main() {
  setUpAll(loadPreviewFonts);

  /// [at] 시각에 [enter]로 장소에 들어가 [seconds]초 흐른 장면을 찍는다.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    DateTime at, {
    FutureOr<bool> Function(PetController c)? enter,
    double seconds = 4,
    Duration away = const Duration(days: 20),
    Pet Function(Pet pet)? prepare,
    Duration settle = Duration.zero,
    WeatherService? weather,
  }) async {
    // 테스트 폰 Flip의 방 칸 크기(논리 픽셀).
    tester.view.physicalSize = const Size(366 * 3, 400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = at;
    final pet = (await tester.runAsync(
      () => db.createPet(
        name: '노을',
        stage: PetStage.adult,
        furMain: 0xFFB5582E,
        furSecond: 0xFFF5EDE2,
        marking: 0xFF8A3A1A,
        now: at.subtract(const Duration(days: 20)),
      ),
    ))!;
    var seen = pet.copyWith(lastSeenAt: at.subtract(away));
    if (prepare != null) seen = prepare(seen);
    await tester.runAsync(() => db.savePet(seen));
    final c = PetController(
      db,
      seen,
      random: Random(1),
      clock: () => now,
      weatherService: weather,
    );
    c.wake();
    // 방에 둔 물건·홈캠처럼 열 때 비동기로 챙기는 것까지 끝난 뒤에 들어간다.
    // 물고 온 물건을 내밀고 있으면 장소에 못 가니 먼저 받는다.
    await tester.runAsync(() async {
      await c.collected;
      // 지난 일기 쓰기처럼 열 때 시작한 일이 가짜 시계 쪽으로 넘어가면 DB가 멈춰 테스트가 끝나지 않았다.
      await c.settled;
      for (
        var p = c.presenting;
        p != null && p.source != FindSource.window;
        p = c.presenting
      ) {
        await c.receive();
      }
    });
    // 연 뒤 이만큼 지난 때 장소에 들어간다(열고 조금 뒤에 하는 일을 찍을 때).
    now = now.add(settle);
    if (enter != null) {
      final ok = await tester.runAsync(() async => await enter(c));
      expect(ok, isTrue, reason: name);
    }
    final game = PetGame(c);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: _key,
          child: GameWidget(game: game),
        ),
      ),
    );
    // 그림 시트를 읽고 칠하는 건 진짜 비동기라 runAsync로 기다린다.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    final frames = (seconds * 30).round();
    for (var i = 0; i < frames; i++) {
      now = now.add(const Duration(milliseconds: 33));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        // 걷기는 게임 속 강아지가 도착하면 끝난다. 여기선 그대로 둔다.
      }
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(tester.takeException(), isNull);

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_key),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('shots').createSync(recursive: true);
      File('shots/scene_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }

  testWidgets('방', (tester) async {
    await shoot(tester, 'room', DateTime(2026, 10, 5, 10, 30));
  });

  testWidgets('카페', (tester) async {
    await shoot(
      tester,
      'cafe',
      DateTime(2026, 10, 5, 10, 30),
      enter: (c) => c.goToCafe(),
    );
  });

  testWidgets('카페 첫 만남(펫이 손님 앞에 앉은 장면)', (tester) async {
    await shoot(
      tester,
      'cafe_meet',
      DateTime(2026, 10, 5, 10, 30),
      enter: (c) async {
        if (!c.goToCafe()) return false;
        // 만남 기록을 저장한 뒤에야 만남 장면이 입장 걷기 뒤에 붙는다.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return c.cafeNote.isNotEmpty;
      },
      seconds: 9,
    );
  });

  testWidgets('금요일 유치원 발표회(친구들이 앉아서 본다)', (tester) async {
    await shoot(
      tester,
      'recital',
      DateTime(2026, 10, 9, 10, 30),
      enter: (c) {
        c.tricks[Trick.sit] = const TrickProgress(
          attempts: 3,
          successes: 3,
          days: 1,
        );
        c.tricks[Trick.spin] = const TrickProgress(
          attempts: 4,
          successes: 3,
          days: 1,
        );
        c.stats = c.stats.copyWith(energy: 90);
        return c.goToKindergarten() && c.startRecital();
      },
      seconds: 5,
    );
  });

  testWidgets('발표회 도장판(방 벽)', (tester) async {
    await shoot(
      tester,
      'stamps',
      DateTime(2026, 10, 9, 15),
      enter: (c) {
        c.tricks[Trick.sit] = const TrickProgress(
          attempts: 3,
          successes: 3,
          days: 1,
        );
        c.stats = c.stats.copyWith(energy: 90);
        if (!c.goToKindergarten() || !c.startRecital()) return false;
        // 무대까지 걸어가기는 게임 속 강아지가 닿아야 끝난다. 여기선 바로 닿은 걸로 한다.
        for (var i = 0; i < 60 && c.step.tag != StepTag.stamp; i++) {
          if (c.step.behavior == Behavior.walk) {
            c.arrived();
          } else {
            c.tick(1);
          }
        }
        c.comeHome();
        return c.recitalStamps.isNotEmpty;
      },
      // 도장 받을 때 뜬 말풍선이 사라진 뒤(도장판을 가리지 않게).
      seconds: 8,
    );
  });

  testWidgets('손 베개(가족 사이, 손을 베고 눕기)', (tester) async {
    await shoot(
      tester,
      'hand',
      DateTime(2026, 10, 5, 15),
      away: const Duration(minutes: 30),
      prepare: (p) => p.copyWith(affection: 80),
      enter: (c) {
        c.stats = c.stats.copyWith(energy: 90, hunger: 20);
        c.step = const PetStep(Behavior.idle, 3);
        c.offerHand(0.55);
        // 달려가기는 게임 속 강아지가 닿아야 끝난다. 여기선 바로 닿은 걸로 한다.
        for (var i = 0; i < 10 && c.step.tag != StepTag.hand; i++) {
          if (c.step.behavior == Behavior.run) {
            c.arrived();
          } else {
            c.tick(1);
          }
        }
        return c.step.tag == StepTag.hand;
      },
      seconds: 2.5,
    );
  });

  testWidgets('자는 자리(친해진 펫은 밤에 문 앞에서 잔다)', (tester) async {
    await shoot(
      tester,
      'sleep_spot',
      DateTime(2026, 10, 5, 23, 40),
      away: const Duration(hours: 3),
      prepare: (p) => p.copyWith(affection: 50),
      enter: (c) => c.petX < 0.3,
      seconds: 2,
    );
  });

  testWidgets('숨긴 보물(가족이 된 날 방석 밑에서 꺼내 문다)', (tester) async {
    await shoot(
      tester,
      'hidden',
      DateTime(2026, 10, 5, 15),
      away: const Duration(minutes: 30),
      prepare: (p) => p.copyWith(affection: 80),
      settle: const Duration(seconds: 15),
      enter: (c) async {
        c.stats = c.stats.copyWith(energy: 90, hunger: 20);
        for (
          var i = 0;
          i < 30 && c.presenting?.source != FindSource.hidden;
          i++
        ) {
          if (c.step.behavior == Behavior.walk ||
              c.step.behavior == Behavior.run) {
            c.arrived();
          } else {
            c.tick(1);
          }
          await Future<void>.delayed(Duration.zero);
        }
        return c.presenting?.source == FindSource.hidden;
      },
      seconds: 2,
    );
  });

  // 아침 현관 소식: 비 예보 날 우산을 물고 현관에 와서 앉은 때와, 내려놓은 뒤 현관에 놓인 우산.
  final rainy = WeatherService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'current': {'temperature_2m': 14.0, 'weather_code': 61},
          'daily': {
            'precipitation_probability_max': [90],
            'temperature_2m_min': [11.0],
          },
        }),
        200,
      ),
    ),
  );
  Pet nearby(Pet p) => p.copyWith(
    latitude: const Value(37.5),
    longitude: const Value(127.0),
    pawMarks: const Value('hidden'),
    quirk: const Value('sitBeforeEat'),
  );
  for (final (name, placed) in [('door_carry', false), ('door_floor', true)]) {
    testWidgets('아침 현관 소식: ${placed ? '현관에 놓인 우산' : '우산을 물고 현관에'}', (
      tester,
    ) async {
      await shoot(
        tester,
        name,
        DateTime(2026, 10, 5, 8),
        away: const Duration(minutes: 20),
        prepare: nearby,
        weather: rainy,
        settle: const Duration(seconds: 15),
        enter: (c) {
          c.stats = c.stats.copyWith(energy: 90, hunger: 20);
          bool done() => placed
              ? c.doorItem != null && c.step.behavior == Behavior.happy
              : c.step.tag == StepTag.door && c.step.behavior == Behavior.sit;
          for (var i = 0; i < 40 && !done(); i++) {
            if (c.step.behavior == Behavior.walk ||
                c.step.behavior == Behavior.run) {
              c.arrived();
            } else {
              c.tick(1);
            }
          }
          return done();
        },
        seconds: 1.5,
      );
    });
  }

  testWidgets('버릇: 다 먹고 빈 그릇 킁킁(그릇이 그대로 있다)', (tester) async {
    await shoot(
      tester,
      'quirk_bowl',
      DateTime(2026, 10, 5, 15),
      away: const Duration(minutes: 30),
      prepare: (p) => p.copyWith(
        quirk: const Value('sniffBowlAfter'),
        pawMarks: const Value('hidden'),
      ),
      enter: (c) {
        c.stats = c.stats.copyWith(hunger: 80);
        c.interact(Interaction.feed);
        for (var i = 0; i < 3; i++) {
          c.tick(1);
        }
        return c.step.tag == StepTag.bowl;
      },
      seconds: 1,
    );
  });

  testWidgets('꾸미기(하늘 목걸이·민트 방석)', (tester) async {
    await shoot(
      tester,
      'dress',
      DateTime(2026, 10, 5, 15),
      away: const Duration(minutes: 30),
      prepare: (p) => p.copyWith(paws: 40),
      enter: (c) {
        c.buyCosmetic('collar_sky');
        c.buyCosmetic('rug_mint');
        c.step = const PetStep(Behavior.sit, 30);
        return c.rug.id == 'rug_mint';
      },
      seconds: 2,
    );
  });

  testWidgets('오늘의 소원(공 아이콘 생각 풍선)', (tester) async {
    await shoot(
      tester,
      'wish',
      DateTime(2026, 10, 5, 15),
      away: const Duration(minutes: 30),
      prepare: (p) => p.copyWith(
        wish: const Value('ball'),
        wishDay: const Value('2026-10-05'),
        wishDone: false,
      ),
      enter: (c) {
        c.stats = c.stats.copyWith(energy: 90, hunger: 20);
        c.step = const PetStep(Behavior.sit, 30);
        return c.openWish != null;
      },
      // 반김 하트가 사라진 뒤(소원 풍선은 24초마다 5초 뜬다).
      seconds: 4.5,
    );
  });

  testWidgets('유치원 CCTV', (tester) async {
    await shoot(
      tester,
      'kindergarten',
      DateTime(2026, 10, 5, 10, 30),
      enter: (c) => c.goToKindergarten() && c.dropOff(),
    );
  });

  testWidgets('간식 가게', (tester) async {
    await shoot(
      tester,
      'shop',
      DateTime(2026, 10, 5, 15),
      enter: (c) => c.goToTreatShop(),
      seconds: 30,
    );
  });

  testWidgets('꿈 풍선(오늘 만난 친구)', (tester) async {
    await shoot(
      tester,
      'dream',
      DateTime(2026, 10, 5, 23, 30),
      enter: (c) async {
        // 밤이라 자고 있던 펫을 깨워 카페에 다녀오게 한다. 만남 기록은 비동기라 잠깐 기다린다.
        c.step = const PetStep(Behavior.idle, 3);
        c.stats = c.stats.copyWith(energy: 80);
        if (!c.goToCafe()) return false;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        c.comeHome();
        c.step = const PetStep(Behavior.sleep, 60);
        return c.metToday.isNotEmpty;
      },
      seconds: 6,
    );
  });

  testWidgets('홈캠 다시보기', (tester) async {
    await shoot(
      tester,
      'homecam',
      DateTime(2026, 10, 5, 19, 30),
      away: const Duration(hours: 11),
      enter: (c) {
        c.startReplay();
        return c.replaying;
      },
      seconds: 5,
    );
  });

  testWidgets('병원 검진', (tester) async {
    await shoot(
      tester,
      'hospital',
      DateTime(2026, 10, 5, 15),
      enter: (c) => c.goToHospital() && c.startCheckup() != null,
      seconds: 6,
    );
  });
}
