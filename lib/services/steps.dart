import 'dart:async';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// 폰 걸음 센서. 산책 세션 동안 차이를 세고, 앱을 열 때 누적값을 한 번 읽는다.
class StepCounter {
  // pedometer는 게터를 부를 때마다 채널 구독을 새로 만들어서, 뒤에 붙은 구독이 앞 구독을 끊는다.
  // 산책 중에 누적값을 읽어도 산책 걸음이 멈추지 않게 스트림 하나를 나눠 쓴다.
  static final Stream<StepCount> _counts = Pedometer.stepCountStream;

  StreamSubscription<StepCount>? _sub;
  int _session = 0;

  Future<bool> start(void Function(int steps) onSteps) async {
    stop();
    final session = _session;
    final status = await Permission.activityRecognition.request();
    // 권한 창을 기다리는 사이 끝내거나 새로 시작한 산책의 응답은 버린다.
    if (session != _session || !status.isGranted) return false;
    int? base;
    _sub = _counts.listen((e) {
      if (session != _session) return;
      base ??= e.steps;
      onSteps(e.steps - base!);
    }, onError: (_) {});
    return true;
  }

  /// 센서는 구독을 시작할 때 지금 누적값을 바로 준다. 권한 요청은 화면이 한 번만 하므로 여기서는 묻지 않는다.
  static Future<int?> readTotal() async {
    if (!await Permission.activityRecognition.isGranted) return null;
    final done = Completer<int?>();
    void finish(int? v) {
      if (!done.isCompleted) done.complete(v);
    }

    final sub = _counts.listen(
      (e) => finish(e.steps),
      onError: (_) => finish(null),
    );
    // Future.timeout은 밑의 구독을 끊지 않아 센서가 계속 켜져 있으므로 직접 끊는다.
    final timer = Timer(const Duration(seconds: 3), () => finish(null));
    final total = await done.future;
    timer.cancel();
    await sub.cancel();
    return total;
  }

  static Future<bool> isGranted() => Permission.activityRecognition.isGranted;

  static Future<bool> request() async =>
      (await Permission.activityRecognition.request()).isGranted;

  void stop() {
    _session++;
    _sub?.cancel();
    _sub = null;
  }
}
