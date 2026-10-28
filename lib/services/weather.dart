import 'dart:convert';

import 'package:http/http.dart' as http;

import 'regions.dart';

enum Sky { clear, cloudy, rain, snow }

class Weather {
  const Weather({
    required this.sky,
    required this.tempC,
    required this.fetchedAt,
    this.rainChance,
    this.lowC,
    this.pm25,
    this.pm10,
  });

  final Sky sky;
  final double tempC;
  final DateTime fetchedAt;

  /// 오늘 비 올 확률 중 가장 높은 값(%). 예보를 못 받았으면 null.
  final int? rainChance;

  /// 오늘 최저기온.
  final double? lowC;

  /// 지금 초미세먼지·미세먼지(µg/m³). 못 받았으면 null.
  final double? pm25, pm10;

  bool get hot => tempC >= 30;
  bool get cold => tempC <= 0;

  /// 에어코리아 예보 등급 '나쁨' 이상(초미세먼지 36, 미세먼지 81 µg/m³부터).
  bool get dusty => (pm25 ?? 0) >= 36 || (pm10 ?? 0) >= 81;

  String get label {
    final s = switch (sky) {
      Sky.clear => '맑음',
      Sky.cloudy => '흐림',
      Sky.rain => '비',
      Sky.snow => '눈',
    };
    return '$s ${tempC.round()}도';
  }
}

class Place {
  const Place({
    required this.name,
    required this.region,
    required this.lat,
    required this.lon,
  });

  final String name;
  final String region;
  final double lat;
  final double lon;

  String get label => region.isEmpty ? name : '$name, $region';
}

/// Open-Meteo. 키가 필요 없고 무료다. 실패하면 예외 대신 빈 결과나 null을 돌려준다.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // 시·군·구는 앱 안에서 바로. Open-Meteo는 '서울'·'관악구' 같은 한국 이름을 못 찾는다.
    final local = searchKorea(q);
    if (local.isNotEmpty) return local;
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '6',
      'language': 'ko',
      'format': 'json',
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const [];
      final results =
          (jsonDecode(utf8.decode(res.bodyBytes))
              as Map<String, dynamic>)['results'];
      if (results is! List) return const [];
      return [
        for (final r in results.whereType<Map<String, dynamic>>())
          Place(
            name: r['name'] as String? ?? '',
            region: [r['admin1'], r['country']].whereType<String>().join(' '),
            lat: (r['latitude'] as num).toDouble(),
            lon: (r['longitude'] as num).toDouble(),
          ),
      ];
    } on Exception {
      return const [];
    }
  }

  /// 지금 날씨와 오늘 예보(비 확률·최저기온), 미세먼지. 미세먼지는 따로 받아서 못 받아도 날씨는 준다.
  Future<Weather?> current(double lat, double lon, DateTime now) async {
    final at = {'latitude': '$lat', 'longitude': '$lon', 'timezone': 'auto'};
    final forecast = Uri.https('api.open-meteo.com', '/v1/forecast', {
      ...at,
      'current': 'temperature_2m,weather_code',
      'daily': 'precipitation_probability_max,temperature_2m_min',
      'forecast_days': '1',
    });
    final air = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      ...at,
      'current': 'pm10,pm2_5',
    });
    final (body, dust) = await (_json(forecast), _json(air)).wait;
    final cur = body?['current'];
    if (cur is! Map) return null;
    final code = cur['weather_code'], temp = cur['temperature_2m'];
    if (code is! num || temp is! num) return null;
    final daily = body?['daily'];
    final pm = dust?['current'];
    return Weather(
      sky: skyFromCode(code.toInt()),
      tempC: temp.toDouble(),
      fetchedAt: now,
      rainChance: _today(daily, 'precipitation_probability_max')?.round(),
      lowC: _today(daily, 'temperature_2m_min')?.toDouble(),
      pm25: pm is Map && pm['pm2_5'] is num
          ? (pm['pm2_5'] as num).toDouble()
          : null,
      pm10: pm is Map && pm['pm10'] is num
          ? (pm['pm10'] as num).toDouble()
          : null,
    );
  }

  /// 실패하거나 모양이 다르면 예외 대신 null.
  Future<Map<String, dynamic>?> _json(Uri uri) async {
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } on Exception {
      return null;
    }
  }

  static num? _today(Object? daily, String key) {
    if (daily is! Map) return null;
    final values = daily[key];
    if (values is! List || values.isEmpty) return null;
    final v = values.first;
    return v is num ? v : null;
  }
}

/// WMO 날씨 코드를 네 가지로 줄인다.
Sky skyFromCode(int code) {
  if (code == 0) return Sky.clear;
  if (code <= 3 || code == 45 || code == 48) return Sky.cloudy;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return Sky.snow;
  return Sky.rain;
}
