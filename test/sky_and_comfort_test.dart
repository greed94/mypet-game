import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/sky.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/services/weather.dart';

void main() {
  group('달', () {
    test('알려진 삭과 보름에 맞는다', () {
      final newMoon = moonPhase(DateTime.utc(2024, 1, 11, 12));
      expect(min(newMoon, 1 - newMoon), lessThan(0.03));
      expect(moonPhase(DateTime.utc(2024, 1, 25, 18)), closeTo(0.5, 0.03));
    });

    test('겨울은 7월부터 이듬해 6월까지 한 해로 센다', () {
      expect(winterOf(DateTime(2026, 12, 1)), 2026);
      expect(winterOf(DateTime(2027, 1, 15)), 2026);
      expect(winterOf(DateTime(2027, 7, 1)), 2027);
    });
  });

  test('지친 말은 위로 선물로 잇고, 평범한 말은 아니다', () {
    expect(needsComfort('오늘 너무 힘들 었어'), isTrue);
    expect(needsComfort('회사에서 스트레스 받았어'), isTrue);
    expect(needsComfort('산책 갈까?'), isFalse);
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = DateTime(2026, 9, 26, 14);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 9, 26, 14);
    });
    // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> make({WeatherService? weather}) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
        latitude: weather == null ? null : 37.5,
        longitude: weather == null ? null : 127.0,
      );
      pet = pet.copyWith(lastSeenAt: now);
      await db.savePet(pet);
      return PetController(
        db,
        pet,
        weatherService: weather,
        random: Random(1),
        clock: () => now,
      );
    }

    test('지친 말을 하면 다음에 열 때 선물 하나를 챙겨 온다', () async {
      var c = await make();
      c.wake();
      await c.collected;
      await c.talk('오늘 진짜 힘들었어');
      expect(c.carried, isEmpty);
      c.sleepApp();
      await pumpEventQueue();

      now = now.add(const Duration(hours: 1));
      c = PetController(
        db,
        (await db.loadPet())!,
        random: Random(2),
        clock: () => now,
      );
      c.wake();
      await c.collected;
      expect(c.carried.where((i) => i.gift), hasLength(1));
      expect(c.pet.comfortDue, isFalse);
    });

    test('위기 표현은 상담 안내가 먼저이고 선물로 잇지 않는다', () async {
      final c = await make();
      c.wake();
      await c.collected;
      expect(await c.talk('죽고 싶어'), TalkOutcome.crisis);
      expect(c.pet.comfortDue, isFalse);
    });

    test('올겨울 첫눈이면 창가로 가고 그날 코 자국이 남는다', () async {
      now = DateTime(2026, 12, 3, 14);
      final weather = WeatherService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'current': {'temperature_2m': -1.0, 'weather_code': 71},
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final c = await make(weather: weather);
      c.wake();
      await pumpEventQueue();
      expect(c.weather?.sky, Sky.snow);
      expect(c.noseOnWindow, isTrue);
      expect(c.step.behavior, Behavior.watchWindow);
      expect((await db.eventsOn(now)).map((e) => e.kind), contains('snow'));
    });
  });
}
