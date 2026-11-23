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

  void attachSensor() {
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
  }

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
    attachSensor();
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

  test('한 권한 창을 주머니·새 산책과 공유하고 마지막 산책만 센서를 구독한다', () async {
    final oldSteps = <int>[];
    final newSteps = <int>[];
    final old = counter.start(oldSteps.add);
    await pumpEventQueue();
    final current = counter.start(newSteps.add);
    await pumpEventQueue();
    final pocket = StepCounter.request();
    await pumpEventQueue();
    expect(requests, hasLength(1));
    requests.single.complete({19: 1});
    expect(await pocket, isTrue);
    expect(await current, isTrue);
    await pumpEventQueue();
    await emit(200);
    await emit(204);
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

  test('권한 채널 오류는 산책과 다음 앱 열기를 중단하지 않는다', () async {
    messenger.setMockMethodCallHandler(permissions, (_) async {
      throw PlatformException(code: 'platform_unavailable');
    });
    var unavailable = 0;
    expect(
      await counter.start(
        (_) => fail('센서 응답 없음'),
        onUnavailable: () => unavailable++,
      ),
      isFalse,
    );
    expect(unavailable, 1);
    expect(await StepCounter.readTotal(), isNull);
    expect(await StepCounter.isGranted(), isFalse);
    expect(await StepCounter.request(), isFalse);
    expect(listens, 0);
  });

  test('일시 단절과 누적값 초기화가 있어도 확인한 걸음만 계속 더한다', () async {
    final steps = <int>[];
    var unavailable = 0;
    final starting = counter.start(
      steps.add,
      onUnavailable: () => unavailable++,
    );
    await pumpEventQueue();
    requests.single.complete({19: 1});
    expect(await starting, isTrue);
    await pumpEventQueue();
    await emit(400);
    await emit(406);
    events.error(code: 'sensor_offline');
    events.error(code: 'sensor_offline');
    await pumpEventQueue();
    expect(unavailable, 1);
    await emit(410);
    await emit(2);
    await emit(5);
    expect(unavailable, 2);
    expect(steps, [0, 6, 10, 10, 13]);
    counter.stop();
    await pumpEventQueue();
    expect(cancels, 1);
  });

  test('네이티브 센서가 종료되면 다음 산책은 새 채널에서 걸음 수집을 다시 시작한다', () async {
    var gaps = 0;
    final first = counter.start((_) {}, onUnavailable: () => gaps++);
    await pumpEventQueue();
    requests.single.complete({19: 1});
    expect(await first, isTrue);
    await pumpEventQueue();
    await emit(10);
    events.endOfStream();
    await pumpEventQueue();
    expect(gaps, 1);
    // Flutter의 모의 드라이버는 endOfStream과 함께 sink도 닫는다.
    attachSensor();
    final steps = <int>[];
    final second = counter.start(steps.add);
    await pumpEventQueue();
    requests.last.complete({19: 1});
    expect(await second, isTrue);
    await pumpEventQueue();
    expect(listens, 2);
    await emit(940);
    await emit(943);
    expect(steps, [0, 3]);
  });

  testWidgets('권한 창에서 보낸 시간도 걸음 수집을 기다린 시간에 포함한다', (tester) async {
    var gaps = 0;
    final pending = counter.start((_) {}, onUnavailable: () => gaps++);
    await tester.pump(const Duration(seconds: 30));
    expect(gaps, 1);
    expect(listens, 0);
    requests.single.complete({19: 1});
    await tester.pump();
    expect(await pending, isTrue);
    expect(listens, 1);
    counter.stop();
    await tester.pump();
  });

  testWidgets('처음 응답이 없는 센서는 시간 기록으로 바꾸고 종료 뒤에는 호출하지 않는다', (tester) async {
    var unavailable = 0;
    final steps = <int>[];
    final starting = counter.start(
      steps.add,
      onUnavailable: () => unavailable++,
    );
    await tester.pump();
    requests.single.complete({19: 1});
    await tester.pump();
    expect(await starting, isTrue);
    await tester.pump(const Duration(seconds: 9));
    expect(unavailable, 1);
    expect(steps, isEmpty);
    expect(listens, 1);
    counter.stop();
    await tester.pump(const Duration(seconds: 12));
    expect(unavailable, 1);
    expect(cancels, 1);
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
