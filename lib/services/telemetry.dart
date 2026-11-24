import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 테스트 빌드 전용 사용 기록. 버튼, 화면 이동, 펫 상태를 Firebase 분석으로, 오류를 오류 보고로 보낸다.
/// 대화·속마음·기억·일기 본문은 보내지 않고 길이나 종류만 보낸다.
/// MYPET_TELEMETRY가 없는 빌드(스토어용)에서는 아무것도 하지 않는다. 수집은 매니페스트에서 기본으로 꺼 두고 여기서만 켠다.
class Telemetry {
  static const _offKey = 'telemetry_off';
  static const _storage = FlutterSecureStorage();
  static const buildEnabled = String.fromEnvironment('MYPET_TELEMETRY') != '';

  static FirebaseAnalytics? _analytics;
  static final _captureKey = Object();

  /// 합성 검사에서는 같은 직렬화 결과를 검사하고 Firebase로 보내지 않는다.
  @visibleForTesting
  static R captureEvents<R>(
    void Function(String, Map<String, Object>) sink,
    R Function() action,
  ) => runZoned(action, zoneValues: {_captureKey: sink});

  static bool get active => _analytics != null;

  /// 사용 기록을 켠 테스트폰에서만 종료 입력과 직후 상태를 logcat에 남긴다.
  static void logPlayMenuClose({required bool atCafe, required bool open}) {
    if (!active) return;
    debugPrint(
      'MypetQA play_close place=${atCafe ? 'cafe' : 'home'} menu_open=$open',
    );
  }

  /// 빌드에 켜져 있고 유저가 끄지 않았을 때만 켠다. Firebase가 안 뜨면 기록 없이 앱만 돈다.
  static Future<void> start() async {
    if (!buildEnabled || await isUserOff()) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _analytics = analytics;
    } catch (_) {
      _analytics = null;
    }
  }

  static Future<bool> isUserOff() async {
    try {
      return await _storage.read(key: _offKey) == 'true';
    } on Exception {
      return false;
    }
  }

  static Future<void> setUserOff(bool off) async {
    await _storage.write(key: _offKey, value: off ? 'true' : 'false');
    if (!off) {
      await start();
      track('telemetry_on');
      return;
    }
    track('telemetry_off');
    try {
      await _analytics?.setAnalyticsCollectionEnabled(false);
      if (Firebase.apps.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          false,
        );
      }
    } catch (_) {
      // 끄는 중 실패해도 다음 실행부터는 켜지 않는다.
    }
    _analytics = null;
  }

  static void track(String type, [Map<String, Object?> data = const {}]) {
    final a = _analytics;
    final sink =
        Zone.current[_captureKey]
            as void Function(String, Map<String, Object>)?;
    if (a == null && sink == null) return;
    final name = _eventName(type);
    final parameters = _params(data);
    if (sink != null) {
      sink(name, Map.unmodifiable(parameters));
      return;
    }
    a!.logEvent(name: name, parameters: parameters).catchError((Object _) {});
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    if (_analytics == null) return;
    FirebaseCrashlytics.instance
        .recordFlutterError(details)
        .catchError((Object _) {});
  }

  static void recordError(Object error, StackTrace stack) {
    if (_analytics == null) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: true)
        .catchError((Object _) {});
  }

  // Firebase 분석이 따로 쓰는 이름(error, session_start 등)과 겹치면 버려지므로 앞에 표시를 붙인다.
  static const _reserved = {
    'error',
    'first_open',
    'session_start',
    'user_engagement',
    'screen_view',
    'app_update',
    'app_remove',
    'app_exception',
  };

  static String _eventName(String type) =>
      _reserved.contains(type) ? 'mp_$type' : type;

  /// 분석은 문자열·숫자만, 한 이벤트에 25개까지, 문자열은 100자까지 받는다.
  static Map<String, Object> _params(Map<String, Object?> data) {
    final out = <String, Object>{};
    for (final MapEntry(:key, :value) in data.entries) {
      if (out.length == 25) break;
      final Object? v = switch (value) {
        null => null,
        num() => value,
        bool() => value ? 1 : 0,
        Iterable() => value.join(','),
        _ => value.toString(),
      };
      if (v == null) continue;
      out[key] = v is String && v.length > 100 ? v.substring(0, 100) : v;
    }
    return out;
  }
}
