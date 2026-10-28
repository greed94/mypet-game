import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/door_news.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/services/weather.dart';

Weather sky(
  Sky s, {
  double temp = 15,
  int? rain,
  double? low,
  double? pm25,
  double? pm10,
}) => Weather(
  sky: s,
  tempC: temp,
  fetchedAt: DateTime(2026, 10, 6, 8),
  rainChance: rain,
  lowC: low,
  pm25: pm25,
  pm10: pm10,
);

/// 예보와 미세먼지를 주소마다 따로 돌려주는 가짜 Open-Meteo.
WeatherService fakeWeather({
  int code = 61,
  double temp = 15,
  int rain = 80,
  double low = 12,
  Object? air = const {'pm2_5': 10.0, 'pm10': 20.0},
  int airStatus = 200,
}) => WeatherService(
  client: MockClient((req) async {
    if (req.url.host.startsWith('air-quality')) {
      return http.Response(jsonEncode({'current': air}), airStatus);
    }
    return http.Response(
      jsonEncode({
        'current': {'temperature_2m': temp, 'weather_code': code},
        'daily': {
          'precipitation_probability_max': [rain],
          'temperature_2m_min': [low],
        },
      }),
      200,
    );
  }),
);

void main() {
  group('규칙', () {
    test('비·눈이거나 비 올 확률 60%부터 우산, 미세먼지 나쁨이면 마스크, 최저 3도 밑이면 목도리', () {
      expect(doorItemFor(sky(Sky.rain)), DoorItem.umbrella);
      expect(doorItemFor(sky(Sky.snow, temp: -2)), DoorItem.umbrella);
      expect(doorItemFor(sky(Sky.cloudy, rain: 60)), DoorItem.umbrella);
      expect(doorItemFor(sky(Sky.cloudy, rain: 59)), isNull);
      expect(doorItemFor(sky(Sky.clear, pm25: 36)), DoorItem.mask);
      expect(doorItemFor(sky(Sky.clear, pm25: 35, pm10: 81)), DoorItem.mask);
      expect(doorItemFor(sky(Sky.clear, pm25: 35, pm10: 80)), isNull);
      expect(doorItemFor(sky(Sky.clear, low: 2.9)), DoorItem.scarf);
      expect(doorItemFor(sky(Sky.clear, low: 3)), isNull);
      // 예보를 못 받았으면 지금 기온으로.
      expect(doorItemFor(sky(Sky.clear, temp: 1)), DoorItem.scarf);
      // 비가 오면 미세먼지·추위보다 우산이 먼저.
      expect(doorItemFor(sky(Sky.rain, pm25: 80, low: -5)), DoorItem.umbrella);
      expect(doorItemFor(sky(Sky.clear, pm25: 80, low: -5)), DoorItem.mask);
    });

    test('아침은 펫의 하루가 바뀌는 5시부터 정오 전까지', () {
      expect(doorMorning(DateTime(2026, 10, 6, 4, 59)), isFalse);
      expect(doorMorning(DateTime(2026, 10, 6, 5)), isTrue);
      expect(doorMorning(DateTime(2026, 10, 6, 11, 59)), isTrue);
      expect(doorMorning(DateTime(2026, 10, 6, 12)), isFalse);
    });

    test('말은 40자 안, 일기엔 조사까지 맞게', () {
      for (final i in DoorItem.values) {
        expect(doorThought(i).length, lessThanOrEqualTo(40));
      }
      expect(doorPlacedLine(DoorItem.umbrella), '현관에 우산을 물어다 놨다. 비 냄새가 났다');
      expect(doorPlacedLine(DoorItem.mask), startsWith('현관에 마스크를'));
      expect(doorTakenLine(DoorItem.scarf), '현관에 둔 목도리를 주인이 챙겼다');
    });

    test('폰 일기는 때 말을 한 번만 붙이고, 놓은 줄과 챙긴 줄이 둘 다 들어간다', () {
      final diary = localDiary([
        (
          at: DateTime(2026, 10, 6, 8),
          kind: 'door',
          detail: doorPlacedLine(DoorItem.umbrella),
        ),
        (
          at: DateTime(2026, 10, 6, 9),
          kind: 'door_take',
          detail: doorTakenLine(DoorItem.umbrella),
        ),
      ], Random(1))!;
      expect(diary, startsWith('아침에 현관에 우산을'));
      expect(diary, isNot(contains('아침에 아침에')));
      expect(diary, contains(doorTakenLine(DoorItem.umbrella)));
    });

    test('Open-Meteo: 지금 날씨에 오늘 예보와 미세먼지를 붙인다', () async {
      final w = (await fakeWeather(
        code: 3,
        rain: 70,
        low: 1.5,
        air: {'pm2_5': 40.0, 'pm10': 50.0},
      ).current(37.5, 127, DateTime(2026, 10, 6, 8)))!;
      expect(w.sky, Sky.cloudy);
      expect(w.rainChance, 70);
      expect(w.lowC, 1.5);
      expect(w.pm25, 40);
      expect(w.dusty, isTrue);
    });

    test('미세먼지를 못 받아도 날씨는 오고, 모양이 이상한 응답엔 죽지 않고 null', () async {
      final w = await fakeWeather(
        airStatus: 500,
      ).current(37.5, 127, DateTime(2026, 10, 6, 8));
      expect(w?.sky, Sky.rain);
      expect(w?.pm25, isNull);
      expect(w?.dusty, isFalse);

      final broken = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'current': {'temperature_2m': 'x'},
            }),
            200,
          ),
        ),
      );
      expect(await broken.current(37.5, 127, DateTime(2026, 10, 6, 8)), isNull);
    });
  });

  group('컨트롤러', () {
    late AppDatabase db;
    var now = DateTime(2026, 10, 6, 8);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime(2026, 10, 6, 8);
    });
    tearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });

    Future<PetController> make({
      WeatherService? weather,
      bool comfort = false,
    }) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
        latitude: 37.5,
        longitude: 127.0,
      );
      pet = pet.copyWith(
        lastSeenAt: now,
        affection: 50,
        quirk: const Value('sitBeforeEat'),
        pawMarks: const Value('hidden'),
        comfortDue: comfort,
      );
      await db.savePet(pet);
      final c = PetController(
        db,
        pet,
        random: Random(1),
        clock: () => now,
        weatherService: weather ?? fakeWeather(),
      );
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
      return c;
    }

    Future<List<String>> events(String kind) async => [
      for (final e in await db.eventsOn(now))
        if (e.kind == kind) e.detail,
    ];

    /// 시계도 함께 1초씩. 걷기는 닿은 걸로 친다. 새 동작이 시작될 때마다 [each].
    void follow(
      PetController c,
      int seconds, [
      void Function(PetStep step)? each,
    ]) {
      PetStep? last;
      for (var i = 0; i < seconds; i++) {
        if (!identical(c.step, last)) {
          last = c.step;
          each?.call(c.step);
        }
        now = now.add(const Duration(seconds: 1));
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
    }

    test('아침에 비 예보면 연 지 조금 뒤 우산을 물고 현관에 와서 알려 주고 내려놓는다. 정오까지 그대로', () async {
      final c = await make();
      final steps = <PetStep>[];
      follow(c, 40, steps.add);
      final carried = steps.where((s) => s.tag == StepTag.door).toList();
      expect(carried, isNotEmpty);
      expect(carried.first.targetX, closeTo(doorX + 0.06, 1e-9));
      expect(carried.any((s) => s.thought == '비 냄새 나. 이거 챙겨'), isTrue);
      expect(c.doorItem, DoorItem.umbrella);
      expect(c.step.tag, isNot(StepTag.door));
      await pumpEventQueue(times: 20);
      expect(await events('door'), [doorPlacedLine(DoorItem.umbrella)]);

      // 다시 열어도 또 물고 오지 않고, 정오가 되면 치운다.
      c.sleepApp();
      now = DateTime(2026, 10, 6, 10);
      c.wake();
      final again = <PetStep>[];
      follow(c, 40, again.add);
      expect(again.where((s) => s.tag == StepTag.door), isEmpty);
      expect(c.doorItem, DoorItem.umbrella);
      now = DateTime(2026, 10, 6, 12);
      expect(c.doorItem, isNull);
    });

    test('현관 물건을 누르면 챙긴 걸로 하고 "잘 다녀와!"', () async {
      final c = await make();
      follow(c, 40);
      expect(c.doorItem, DoorItem.umbrella);
      c.takeDoorItem();
      expect(c.doorItem, isNull);
      expect(c.step.thought, '잘 다녀와!');
      await pumpEventQueue(times: 20);
      expect(await events('door_take'), [doorTakenLine(DoorItem.umbrella)]);
      expect((await db.loadPet())!.doorNews, endsWith(':-'));
    });

    test('집 밖(카페)에 있을 땐 현관이 안 보여서 챙기기가 되지 않는다', () async {
      final c = await make();
      follow(c, 40);
      expect(c.doorItem, DoorItem.umbrella);
      expect(c.goToCafe(), isTrue);
      c.takeDoorItem();
      expect(c.doorItem, DoorItem.umbrella);
      await pumpEventQueue(times: 20);
      expect(await events('door_take'), isEmpty);
    });

    test('어제 받은 날씨만 남아 있으면(새로 받기 실패) 고르지 않고, 오늘 날씨를 받으면 그때 한다', () async {
      var online = true;
      final flaky = WeatherService(
        client: MockClient((req) async {
          if (!online) return http.Response('', 500);
          return http.Response(
            jsonEncode({
              'current': {'temperature_2m': 14.0, 'weather_code': 61},
              'daily': {
                'precipitation_probability_max': [90],
                'temperature_2m_min': [11.0],
              },
            }),
            200,
          );
        }),
      );
      now = DateTime(2026, 10, 5, 20);
      final c = await make(weather: flaky);
      expect(c.weather, isNotNull);
      c.sleepApp();
      online = false;
      now = DateTime(2026, 10, 6, 8);
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      // 밤새 비워서 온 선물은 먼저 받는다(그게 막는 게 아니라 어제 날씨가 막는지 보려고).
      while (c.presenting != null) {
        await c.receive();
      }
      final steps = <PetStep>[];
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      expect(c.doorItem, isNull);

      online = true;
      c.sleepApp();
      now = now.add(const Duration(minutes: 70));
      c.wake();
      await c.collected;
      await pumpEventQueue(times: 20);
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isNotEmpty);
    });

    test('물건이 없던 아침에도 날씨가 바뀌면(새 예보) 그 아침 안에 다시 본다', () async {
      var rain = 10;
      final changing = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'current': {'temperature_2m': 14.0, 'weather_code': 2},
              'daily': {
                'precipitation_probability_max': [rain],
                'temperature_2m_min': [11.0],
              },
            }),
            200,
          ),
        ),
      );
      final c = await make(weather: changing);
      final steps = <PetStep>[];
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      expect((await db.loadPet())!.doorNews, isNull);

      rain = 80;
      c.sleepApp();
      now = now.add(const Duration(minutes: 70));
      c.wake();
      await pumpEventQueue(times: 20);
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isNotEmpty);
      expect(c.doorItem, DoorItem.umbrella);
    });

    test('정오 1분 전엔 물고 오기 시작하지 않는다(장면 도중 정오가 되면 입에서 사라진다)', () async {
      now = DateTime(2026, 10, 6, 11, 59);
      final c = await make();
      final steps = <PetStep>[];
      follow(c, 30, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
    });

    test('자는 동안 아침이 됐으면 장면 없이 현관에 놓여 있다(밤사이 물어다 둔 것처럼)', () async {
      now = DateTime(2026, 10, 6, 6);
      final c = await make();
      expect(c.doorItem, DoorItem.umbrella);
      final steps = <PetStep>[];
      follow(c, 30, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      expect(await events('door'), [doorPlacedLine(DoorItem.umbrella)]);
    });

    test('맑고 포근한 날은 아무것도 안 둔다', () async {
      final c = await make(weather: fakeWeather(code: 0, rain: 10, low: 12));
      final steps = <PetStep>[];
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      expect(c.doorItem, isNull);
      expect(await events('door'), isEmpty);
    });

    test('오후에 처음 열면 비가 와도 하지 않는다', () async {
      now = DateTime(2026, 10, 6, 14);
      final c = await make();
      final steps = <PetStep>[];
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      expect(c.doorItem, isNull);
    });

    test('날씨를 이미 받아 둔 채 잠깐 껐다 켜도, 열 때 챙겨 온 위로 선물보다 우산을 먼저 물지 않는다', () async {
      final c = await make();
      // 아직 우산을 물고 오기 전에 지친 말을 하고 앱을 닫았다가 5분 뒤 다시 연다(반김 없음).
      await c.talk('오늘 너무 지쳤어');
      c.sleepApp();
      now = now.add(const Duration(minutes: 5));
      c.wake();
      expect(c.step.tag, isNot(StepTag.door));
      await c.collected;
      expect(c.presenting?.source, FindSource.comfort);
      final steps = <PetStep>[];
      follow(c, 30, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
    });

    test('열 때 챙겨 온 물건이 있으면 그걸 받은 뒤에 우산을 물고 온다(입에 둘이 섞이지 않게)', () async {
      final c = await make(comfort: true);
      expect(c.presenting?.source, FindSource.comfort);
      final steps = <PetStep>[];
      follow(c, 30, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isEmpty);
      await c.receive();
      follow(c, 40, steps.add);
      expect(steps.where((s) => s.tag == StepTag.door), isNotEmpty);
    });
  });
}
