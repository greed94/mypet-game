import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/crisis_dialog.dart';

void main() {
  const channel = MethodChannel('mypet/crisis_support');
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCrisisDialog(context),
            child: const Text('도움'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('도움'));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('전화·긴급·문자 안내와 직접 누른 전화 화면 요청만 보낸다', (tester) async {
    final calls = <MethodCall>[];
    final pending = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return pending.future;
        });
    await open(tester);
    expect(find.textContaining('112 또는 119'), findsOneWidget);
    expect(find.textContaining('마들랜'), findsOneWidget);
    expect(calls, isEmpty);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '109 전화 화면 열기'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls.length, 1);
    expect(calls.single.method, 'dial109');
    expect(calls.single.arguments, isNull);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('열지 못했어요'), findsNothing);
  });

  testWidgets('전화 앱을 열지 못하면 번호를 남기고 재시도할 수 있다', (tester) async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          calls++;
          if (calls == 1) throw PlatformException(code: 'synthetic');
          return true;
        });
    await open(tester);
    await tester.tap(find.text('109 전화 화면 열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('전화 앱에서 109'), findsOneWidget);
    await tester.tap(find.text('109 전화 화면 열기'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('열지 못했어요'), findsNothing);
  });

  testWidgets('안내를 닫은 뒤 늦은 전화 앱 응답은 화면을 갱신하지 않는다', (tester) async {
    final pending = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => pending.future);
    await open(tester);
    await tester.tap(find.text('109 전화 화면 열기'));
    await tester.pump();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
