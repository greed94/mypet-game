import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../pet/tricks.dart';

enum PlayAction { open, close, trick, throwBall, treat, notebook }

enum PlayPhase { pointer, cancel, tap, result, frame, error }

/// 테스트 빌드 전용 사용 기록. 버튼, 화면 이동, 펫 상태를 Firebase 분석으로, 오류를 오류 보고로 보낸다.
/// 대화·속마음·기억·일기 본문은 보내지 않고 길이나 종류만 보낸다.
/// MYPET_TELEMETRY가 없는 빌드(스토어용)에서는 아무것도 하지 않는다. 수집은 매니페스트에서 기본으로 꺼 두고 여기서만 켠다.
class Telemetry {
  static const _offKey = 'telemetry_off';
  static const _storage = FlutterSecureStorage();
  static const buildEnabled = String.fromEnvironment('MYPET_TELEMETRY') != '';

  static FirebaseAnalytics? _analytics;
  static final _captureKey = Object();
  static final _playCaptureKey = Object();
  static int _settingsVersion = 0;
  static final _deviceTrace = _PlayJournal(() async {
    if (!Platform.isAndroid) return null;
    final dir = await getExternalStorageDirectory();
    return dir == null ? null : Directory('${dir.path}/mypet-qa');
  }, debugPrintSynchronously);
  static _PlayJournal get _play =>
      Zone.current[_playCaptureKey] as _PlayJournal? ?? _deviceTrace;

  /// 합성 검사에서는 같은 직렬화 결과를 검사하고 Firebase로 보내지 않는다.
  @visibleForTesting
  static R captureEvents<R>(
    void Function(String, Map<String, Object>) sink,
    R Function() action,
  ) => runZoned(action, zoneValues: {_captureKey: sink});

  static bool get active => _analytics != null;
  static bool get playTraceEnabled => _play.enabled;

  /// 입력 하나에서 나온 판정과 실제 그려진 화면을 같은 input 번호로 찾는다.
  static int playTrace(
    PlayAction action,
    PlayPhase phase, {
    int? input,
    Trick? trick,
    Enum? ball,
    bool? atCafe,
    bool? menuOpen,
    int? attempts,
    int? successes,
    int? stars,
    Enum? outcome,
  }) {
    final journal = _play;
    if (!journal.enabled) return 0;
    final number = input ?? journal.nextSequence;
    journal.record(
      [
        'action=${action.name}',
        'phase=${phase.name}',
        'input=$number',
        if (trick != null) 'trick=${trick.name}',
        if (ball != null) 'ball=${ball.name}',
        if (atCafe != null) 'place=${atCafe ? 'cafe' : 'home'}',
        if (menuOpen != null) 'menu_open=$menuOpen',
        if (attempts != null) 'attempts=$attempts',
        if (successes != null) 'successes=$successes',
        if (stars != null) 'stars=$stars',
        if (outcome != null) 'outcome=${outcome.name}',
      ].join(' '),
    );
    return number;
  }

  @visibleForTesting
  static Future<R> capturePlayTrace<R>(
    void Function(String) sink,
    Future<R> Function() action, {
    Directory? directory,
  }) async {
    final journal = _PlayJournal(() async => directory, sink)..start();
    try {
      return await runZoned(action, zoneValues: {_playCaptureKey: journal});
    } finally {
      await journal.pendingWrites;
    }
  }

  /// 로컬 QA 기록은 Firebase 연결보다 먼저 시작한다.
  static Future<void> start() async {
    if (!buildEnabled) return;
    final version = _settingsVersion;
    final off = await isUserOff();
    if (version != _settingsVersion) return;
    if (off) {
      await _play.clear();
      return;
    }
    _play.start();
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final analytics = FirebaseAnalytics.instance;
      await analytics.setAnalyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      if (version == _settingsVersion) _analytics = analytics;
    } catch (_) {
      if (version == _settingsVersion) _analytics = null;
    }
  }

  static Future<bool> isUserOff() async {
    try {
      return await _storage.read(key: _offKey) == 'true';
    } on Exception {
      // 저장소가 잠겨 사용자의 선택을 읽을 수 없으면 수집을 보류한다.
      return true;
    }
  }

  static Future<void> setUserOff(bool off) async {
    _settingsVersion++;
    await Future.wait([
      if (off) _play.clear(),
      _storage.write(key: _offKey, value: off ? 'true' : 'false'),
    ]);
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
    if (_play.enabled) {
      // 이 목록의 이벤트 이름만 기기에 남긴다. 선택값도 앱의 고정 항목만 허용한다.
      final action = switch (type) {
        'tap' when const {'pet', 'feed'}.contains(data['what']) =>
          'tap what=${data['what']}',
        'tab' when const {'home', 'diary', 'collection'}.contains(data['to']) =>
          'tab to=${data['to']}',
        'ball_away' when data['auto'] is bool =>
          'ball_away auto=${data['auto']}',
        'wake' ||
        'pause' ||
        'walk_start' ||
        'walk_end' ||
        'walk_refused' ||
        'place_enter' ||
        'place_leave' ||
        'notebook_open' ||
        'treat' ||
        'ball_out' ||
        'fetch' ||
        'throw' => type,
        _ => null,
      };
      if (action != null) _play.record('event=$action');
    }
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
    _recordFailure('flutter_error', details.exception, details.stack);
    if (_analytics == null) return;
    FirebaseCrashlytics.instance
        .recordFlutterError(details)
        .catchError((Object _) {});
  }

  static void recordError(Object error, StackTrace stack) {
    _recordFailure('unhandled_error', error, stack);
    if (_analytics == null) return;
    FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: true)
        .catchError((Object _) {});
  }

  // 오류 본문과 전체 스택에는 입력이 섞일 수 있다. 앱 소스의 첫 위치만 뽑는다.
  static final _appFrame = RegExp(
    r'package:mypet/([a-zA-Z0-9_/]+\.dart):(\d+)(?::\d+)?',
  );
  static void _recordFailure(String event, Object error, StackTrace? stack) {
    if (!_play.enabled) return;
    final kind = switch (error) {
      StateError() => 'state',
      RangeError() => 'range',
      TypeError() => 'type',
      ArgumentError() => 'argument',
      FileSystemException() => 'file',
      FlutterError() => 'flutter',
      _ => 'other',
    };
    final frame = stack == null ? null : _appFrame.firstMatch(stack.toString());
    final origin = frame == null ? '' : ' origin=${frame[1]}:${frame[2]}';
    _play.record('event=$event kind=$kind$origin');
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

/// logcat은 입력 시점에 출력한다. 파일은 이벤트를 모아 순서대로 기록하며
/// 각각 최대 64 KiB인 현재 파일과 직전 파일만 보관한다.
class _PlayJournal {
  _PlayJournal(this.directory, this.output);
  final Future<Directory?> Function() directory;
  final void Function(String) output;
  Directory? _cachedDirectory;
  static const _limit = 64 * 1024;
  final _queued = Queue<String>();
  Future<void> pendingWrites = Future<void>.value();
  bool enabled = false;
  bool _scheduled = false;
  int _generation = 0;
  int _sequence = 0;
  int _session = 0;
  int get nextSequence => _sequence + 1;

  void start() {
    if (enabled) return;
    enabled = true;
    _session = DateTime.now().microsecondsSinceEpoch;
    _sequence = 0;
    const revision = String.fromEnvironment(
      'MYPET_QA_BUILD',
      defaultValue: 'local',
    );
    final build = RegExp(r'^[a-zA-Z0-9_.-]{1,24}$').hasMatch(revision)
        ? revision
        : 'local';
    record('event=session_start build=$build');
  }

  void record(String fields) {
    if (!enabled) return;
    final time = DateTime.now().toUtc().toIso8601String();
    final line =
        'MypetQA time=$time session=$_session seq=${++_sequence} $fields';
    try {
      output(line);
    } catch (_) {
      // logcat이 안 되더라도 파일을 기록한다.
    }
    // 저장장치가 막혀도 입력 처리를 지연시키거나 메모리를 무한히 쌓지 않는다.
    if (_queued.length == 256) _queued.removeFirst();
    _queued.add(line);
    if (_scheduled) return;
    _scheduled = true;
    final generation = _generation;
    _enqueue(() async {
      if (generation != _generation) return;
      _scheduled = false;
      final lines = _queued.toList();
      _queued.clear();
      final dir = _cachedDirectory ??= await directory();
      if (dir == null || lines.isEmpty) return;
      await dir.create(recursive: true);
      final current = File('${dir.path}/play.log');
      var length = await current.exists() ? await current.length() : 0;
      var batch = StringBuffer();
      for (final line in lines) {
        final bytes = utf8.encode(line).length + 1;
        if (length + bytes > _limit) {
          if (batch.isNotEmpty) {
            await current.writeAsString(
              batch.toString(),
              mode: FileMode.append,
            );
          }
          final previous = File('${dir.path}/play.previous.log');
          if (await previous.exists()) await previous.delete();
          await current.rename(previous.path);
          batch = StringBuffer();
          length = 0;
        }
        batch.writeln(line);
        length += bytes;
      }
      if (batch.isNotEmpty) {
        await current.writeAsString(batch.toString(), mode: FileMode.append);
      }
    });
  }

  Future<void> clear() {
    enabled = false;
    _generation++;
    _scheduled = false;
    _queued.clear();
    _enqueue(() async {
      final dir = _cachedDirectory ??= await directory();
      if (dir == null) return;
      for (final name in ['play.log', 'play.previous.log']) {
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      }
    });
    return pendingWrites;
  }

  void _enqueue(Future<void> Function() work) {
    // 저장 실패는 게임 상태와 다음 파일 쓰기에 영향을 주지 않는다.
    pendingWrites = pendingWrites.then((_) => work()).catchError((Object _) {});
  }
}
