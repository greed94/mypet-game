import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/services/weather.dart';

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('날씨 코드는 네 가지로 줄어든다', () {
    expect(skyFromCode(0), Sky.clear);
    expect(skyFromCode(2), Sky.cloudy);
    expect(skyFromCode(45), Sky.cloudy);
    expect(skyFromCode(61), Sky.rain);
    expect(skyFromCode(95), Sky.rain);
    expect(skyFromCode(73), Sky.snow);
    expect(skyFromCode(85), Sky.snow);
  });

  test('시·군·구는 인터넷 없이 앱 안 목록에서 찾고, 동 이름은 인터넷 검색 결과를 읽는다', () async {
    final offline = WeatherService(
      client: MockClient((_) async => fail('시·군·구는 인터넷에 묻지 않는다')),
    );
    expect((await offline.search(' 서울 ')).first.label, '서울특별시');
    final service = WeatherService(
      client: MockClient((req) async {
        expect(req.url.host, 'geocoding-api.open-meteo.com');
        expect(req.url.queryParameters['name'], '봉천동');
        return json({
          'results': [
            {
              'name': '봉천동',
              'admin1': '서울특별시',
              'country': '대한민국',
              'latitude': 37.48,
              'longitude': 126.95,
            },
          ],
        });
      }),
    );
    final places = await service.search(' 봉천동 ');
    expect(places.single.label, '봉천동, 서울특별시 대한민국');
    expect(places.single.lat, 37.48);
  });

  test('현재 날씨를 읽고, 서버가 이상하면 null을 준다', () async {
    final now = DateTime(2026, 9, 25, 14);
    final ok = WeatherService(
      client: MockClient(
        (_) async => json({
          'current': {'temperature_2m': 31.4, 'weather_code': 61},
        }),
      ),
    );
    final w = (await ok.current(37.5, 127, now))!;
    expect(w.sky, Sky.rain);
    expect(w.hot, isTrue);
    expect(w.label, '비 31도');
    expect(w.fetchedAt, now);

    final broken = WeatherService(
      client: MockClient((_) async => http.Response('<html>', 502)),
    );
    expect(await broken.current(37.5, 127, now), isNull);
    expect(await broken.search('봉천동'), isEmpty);
  });
}
