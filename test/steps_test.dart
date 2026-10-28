import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/services/steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const sensor = EventChannel('step_count');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Completer<Map<int, int>>> requests;
  late MockStreamHandlerEventSink events;
  late int listens;
  late int cancels;
  late StepCounter counter;

  setUp(() {
    requests = [];
    listens = 0;
    cancels = 0;
    counter = StepCounter();
    messenger.setMockMethodCallHandler(permissions, (call) {
      if (call.method == 'checkPermissionStatus') return Future.value(1);
      final response = Completer<Map<int, int>>();
      requests.add(response);
      return response.future;
    });
    messenger.setMockStreamHandler(
      sensor,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          listens++;
          events = sink;
        },
        onCancel: (_) => cancels++,
      ),
    );
  });

  tearDown(() async {
    counter.stop();
    await pumpEventQueue();
    messenger.setMockMethodCallHandler(permissions, null);
  });

  Future<void> emit(int total) async {
    events.success(total);
    await pumpEventQueue();
  }

  test('권한을 기다리다 종료하면 늦은 허용 응답으로 센서를 켜지 않는다', () async {
    final starting = counter.start((_) => fail('이미 끝난 산책'));
    await pumpEventQueue();
    expect(requests, hasLength(1));
    counter.stop();
    requests.single.complete({19: 1});
    expect(await starting, isFalse);
    await pumpEventQueue();
    expect(listens, 0);
  });

  test('권한 응답 순서가 뒤집혀도 새 산책만 걸음을 받고 종료 시 구독을 해제한다', () async {
    final oldSteps = <int>[];
    final newSteps = <int>[];
    final old = counter.start(oldSteps.add);
    await pumpEventQueue();
    final current = counter.start(newSteps.add);
    await pumpEventQueue();
    requests[1].complete({19: 1});
    expect(await current, isTrue);
    await pumpEventQueue();
    await emit(200);
    await emit(204);
    requests[0].complete({19: 1});
    expect(await old, isFalse);
    await emit(205);
    expect(oldSteps, isEmpty);
    expect(newSteps, [0, 4, 5]);
    counter.stop();
    await pumpEventQueue();
    expect(listens, 1);
    expect(cancels, 1);
  });

  test('누적 걸음 읽기와 산책이 센서를 공유하고 읽기 완료 뒤에도 산책은 계속 센다', () async {
    final steps = <int>[];
    final starting = counter.start(steps.add);
    await pumpEventQueue();
    requests.single.complete({19: 1});
    expect(await starting, isTrue);
    await pumpEventQueue();
    await emit(1000);
    await emit(1002);
    final reading = StepCounter.readTotal();
    await pumpEventQueue();
    await emit(1003);
    expect(await reading, 1003);
    await emit(1004);
    expect(steps, [0, 2, 3, 4]);
    expect(listens, 1);
    expect(cancels, 0);
    counter.stop();
    await pumpEventQueue();
    expect(cancels, 1);
  });

  test('진행 중 다시 시작하면 이전 구독을 끝내고 새 누적값을 기준으로 센다', () async {
    final oldSteps = <int>[];
    final newSteps = <int>[];
    final first = counter.start(oldSteps.add);
    await pumpEventQueue();
    requests[0].complete({19: 1});
    expect(await first, isTrue);
    await pumpEventQueue();
    await emit(100);
    await emit(104);
    final next = counter.start(newSteps.add);
    await pumpEventQueue();
    requests[1].complete({19: 1});
    expect(await next, isTrue);
    await pumpEventQueue();
    await emit(110);
    await emit(112);
    expect(oldSteps, [0, 4]);
    expect(newSteps, [0, 2]);
    counter.stop();
    await pumpEventQueue();
    expect(listens, 2);
    expect(cancels, 2);
  });

  test('권한 거절은 센서를 시작하지 않는다', () async {
    final starting = counter.start((_) => fail('권한이 없는 산책'));
    await pumpEventQueue();
    requests.single.complete({19: 0});
    expect(await starting, isFalse);
    await pumpEventQueue();
    expect(listens, 0);
  });
}
