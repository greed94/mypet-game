import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// 폰 걸음 센서. 산책 세션 동안 차이를 세고, 앱을 열 때 누적값을 한 번 읽는다.
class StepCounter {
  // pedometer는 게터를 부를 때마다 채널 구독을 새로 만들어서, 뒤에 붙은 구독이 앞 구독을 끊는다.
  // 산책 중에 누적값을 읽어도 산책 걸음이 멈추지 않게 스트림 하나를 나눠 쓴다.
  static Stream<StepCount>? _sharedCounts;
  static Stream<StepCount> get _counts =>
      _sharedCounts ??= Pedometer.stepCountStream;

  static void _ended(Stream<StepCount> stream) {
    if (identical(_sharedCounts, stream)) _sharedCounts = null;
  }

  StreamSubscription<StepCount>? _sub;
  int _session = 0;
  Timer? _firstSample;
  int? _deviceTotal;
  int? get deviceTotal => _deviceTotal;
  static Future<PermissionStatus>? _pendingPermission;

  static Future<PermissionStatus> _requestPermission() =>
      _pendingPermission ??= Permission.activityRecognition
          .request()
          .whenComplete(() => _pendingPermission = null);

  Future<bool> start(
    void Function(int steps) onSteps, {
    void Function()? onUnavailable,
  }) async {
    stop();
    final session = _session;
    var reported = false;
    void unavailable() {
      if (session != _session || reported) return;
      reported = true;
      onUnavailable?.call();
    }

    // 권한창에 머문 시간도 이미 시작한 산책의 일부다.
    final firstSample = Timer(const Duration(seconds: 8), unavailable);
    _firstSample = firstSample;
    _deviceTotal = null;
    try {
      if (!(await _requestPermission()).isGranted || session != _session) {
        firstSample.cancel();
        return false;
      }
    } on PlatformException {
      firstSample.cancel();
      unavailable();
      return false;
    } on MissingPluginException {
      firstSample.cancel();
      unavailable();
      return false;
    }
    int? last;
    var steps = 0;
    final stream = _counts;
    _sub = stream.listen(
      (e) {
        if (session != _session) return;
        final total = e.steps;
        if (total < 0) {
          unavailable();
          return;
        }
        _firstSample?.cancel();
        final previous = last;
        if (previous != null) {
          if (total < previous) {
            // 기기의 누적값이 초기화됐다. 그 사이 걸음은 추정하지 않는다.
            unavailable();
          } else {
            steps += total - previous;
          }
        }
        last = total;
        _deviceTotal = total;
        reported = false;
        onSteps(steps);
      },
      onError: (_) => unavailable(),
      onDone: () {
        _ended(stream);
        unavailable();
      },
    );
    return true;
  }

  /// 센서는 구독을 시작할 때 지금 누적값을 바로 준다. 권한 요청은 화면이 한 번만 하므로 여기서는 묻지 않는다.
  static Future<int?> readTotal() async {
    if (!await isGranted()) return null;
    final done = Completer<int?>();
    void finish(int? v) {
      if (!done.isCompleted) done.complete(v);
    }

    final stream = _counts;
    final sub = stream.listen(
      (e) => finish(e.steps >= 0 ? e.steps : null),
      onError: (_) => finish(null),
      onDone: () {
        _ended(stream);
        finish(null);
      },
    );
    // Future.timeout은 밑의 구독을 끊지 않아 센서가 계속 켜져 있으므로 직접 끊는다.
    final timer = Timer(const Duration(seconds: 3), () => finish(null));
    final total = await done.future;
    timer.cancel();
    await sub.cancel();
    return total;
  }

  static Future<bool> isGranted() =>
      _permission(() => Permission.activityRecognition.status);

  static Future<bool> request() => _permission(_requestPermission);

  static Future<bool> _permission(
    Future<PermissionStatus> Function() read,
  ) async {
    try {
      return (await read()).isGranted;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void stop() {
    _session++;
    _firstSample?.cancel();
    _firstSample = null;
    _sub?.cancel();
    _sub = null;
  }
}
