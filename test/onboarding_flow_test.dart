import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/data/database.dart';
import 'package:mypet/services/weather.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/onboarding_screen.dart';
import 'package:mypet/ui/shape_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  late Directory folder;
  late File photo;

  setUp(() {
    ShapePicker.resetCache();
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> mount(WidgetTester tester, {http.Client? client}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      folder = await Directory.systemTemp.createTemp('mypet-onboarding-');
      photo = File('${folder.path}/synthetic.png');
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(120, 80, 30));
      await photo.writeAsBytes(img.encodePng(image));
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(picker, null);
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        for (final file in folder.listSync().whereType<File>()) {
          await file.delete();
        }
        await folder.delete();
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: OnboardingScreen(
          db: db,
          weather: WeatherService(
            client: client ?? MockClient((_) async => http.Response('{}', 200)),
          ),
          onCreated: (_) async => fail('This check never creates a real pet'),
        ),
      ),
    );
    await drain(tester);
  }

  Future<void> placePage(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '콩이');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('어디에 살아요?'), findsOneWidget);
  }

  Future<void> pick(WidgetTester tester, List<Object> errors) async {
    final action = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('사진으로 만들기'),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          ),
        )
        .onPressed!;
    await tester.runAsync(() async {
      runZonedGuarded(action, (error, stack) => errors.add(error));
      await pumpEventQueue();
    });
    await tester.pump();
  }

  http.Response places(String name) => http.Response(
    jsonEncode({
      'results': [
        {
          'name': name,
          'admin1': '합성 지역',
          'country': '검사용',
          'latitude': 37.0,
          'longitude': 127.0,
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  testWidgets('처음 사진 선택 중 화면을 닫으면 늦은 사진은 해제된 화면을 갱신하지 않는다', (tester) async {
    await mount(tester);
    final picked = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(picker, (_) => picked.future);
    final errors = <Object>[];
    await pick(tester, errors);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      picked.complete(photo.path);
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect((await tester.runAsync(() => db.loadPet())), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 응답보다 나중에 고른 기본 색을 늦은 사진이 덮지 않는다', (tester) async {
    await mount(tester);
    final picked = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(picker, (_) => picked.future);
    final errors = <Object>[];
    await pick(tester, errors);
    await tester.tap(find.widgetWithText(ChoiceChip, '흰색'));
    await tester.pump();
    await tester.runAsync(() async {
      picked.complete(photo.path);
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '흰색')).selected,
      isTrue,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsNothing,
    );
    expect(find.text('사진으로 만들기'), findsOneWidget);
  });

  testWidgets('처음 사진 선택 실패와 읽기 실패 뒤 다시 정상 사진을 고를 수 있다', (tester) async {
    await mount(tester);
    var attempt = 0;
    messenger.setMockMethodCallHandler(picker, (_) async {
      attempt++;
      if (attempt == 1) throw PlatformException(code: 'test-picker-error');
      if (attempt == 2) return '${folder.path}/missing.png';
      return photo.path;
    });
    final errors = <Object>[];
    await pick(tester, errors);
    await drain(tester);
    expect(find.text('사진을 열지 못했어요. 다시 골라 볼까요?'), findsOneWidget);
    expect(find.text('사진으로 만들기'), findsOneWidget);
    await pick(tester, errors);
    await drain(tester);
    expect(find.text('사진을 읽지 못했어요. 다른 사진으로 해볼까요?'), findsOneWidget);
    expect(find.text('사진으로 만들기'), findsOneWidget);
    await pick(tester, errors);
    await drain(tester);
    expect(errors, isEmpty);
    expect(attempt, 3);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
    expect((await tester.runAsync(() => db.loadPet())), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('취소한 사진 선택은 기본 색을 유지하고 곧바로 다시 열 수 있다', (tester) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    messenger.setMockMethodCallHandler(picker, (_) async => null);
    final errors = <Object>[];
    await pick(tester, errors);
    await drain(tester);
    expect(errors, isEmpty);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '갈색')).selected,
      isTrue,
    );
    expect(find.text('사진으로 만들기'), findsOneWidget);
    messenger.setMockMethodCallHandler(picker, (_) async => photo.path);
    await pick(tester, errors);
    await drain(tester);
    expect(errors, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
  });

  testWidgets('같은 사진 시작 콜백을 연달아 호출해도 선택기는 한 번만 연다', (tester) async {
    await mount(tester);
    final picked = (await tester.runAsync(() async => Completer<String?>()))!;
    var requests = 0;
    messenger.setMockMethodCallHandler(picker, (_) {
      requests++;
      return picked.future;
    });
    final action = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('사진으로 만들기'),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          ),
        )
        .onPressed!;
    final errors = <Object>[];
    await tester.runAsync(() async {
      runZonedGuarded(() {
        action();
        action();
      }, (error, stack) => errors.add(error));
      await pumpEventQueue();
    });
    await tester.pump();
    final countWhileWaiting = requests;
    await tester.runAsync(() async {
      picked.complete(null);
      await pumpEventQueue();
    });
    await drain(tester);
    expect(countWhileWaiting, 1);
    expect(errors, isEmpty);
    expect(find.text('사진으로 만들기'), findsOneWidget);
  });

  testWidgets('검색어만 바꿔도 이전 결과와 선택을 지우고 늦은 응답을 무시한다', (tester) async {
    final pending = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    var requests = 0;
    await mount(
      tester,
      client: MockClient((_) {
        requests++;
        return requests == 1 ? Future.value(places('고른 마을')) : pending.future;
      }),
    );
    await placePage(tester);
    final input = find.widgetWithText(TextField, '동네 이름');
    await tester.enterText(input, 'alpha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(find.textContaining('선택: '), findsOneWidget);
    await tester.enterText(input, 'bravo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    await tester.enterText(input, 'charlie');
    await tester.pump();
    expect(find.textContaining('선택: '), findsNothing);
    expect(find.text('건너뛰고 시작'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
    await tester.runAsync(() async {
      pending.complete(places('오래된 마을'));
      await pumpEventQueue();
    });
    await drain(tester);
    expect(find.textContaining('오래된 마을'), findsNothing);
    expect(find.textContaining('고른 마을'), findsNothing);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('동네 검색 실패 후 다시 검색하고 선택할 수 있다', (tester) async {
    var requests = 0;
    await mount(
      tester,
      client: MockClient((_) async {
        requests++;
        return requests == 1
            ? http.Response('unavailable', 503)
            : places('새 마을');
      }),
    );
    await placePage(tester);
    final input = find.widgetWithText(TextField, '동네 이름');
    await tester.enterText(input, 'alpha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    expect(find.text('찾지 못했어요. 시·구 이름으로 다시 해볼까요?'), findsOneWidget);
    await tester.enterText(input, 'bravo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    expect(requests, 2);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(find.textContaining('선택: '), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    expect((await tester.runAsync(() => db.loadPet())), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('나중에 끝난 이전 동네 검색이 새 검색 결과를 덮지 않는다', (tester) async {
    final first = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    final second = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    final sent = <String>[];
    await mount(
      tester,
      client: MockClient((request) {
        final query = request.url.queryParameters['name']!;
        sent.add(query);
        return query == 'alpha' ? first.future : second.future;
      }),
    );
    await placePage(tester);
    final input = find.widgetWithText(TextField, '동네 이름');
    await tester.enterText(input, 'alpha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    await tester.enterText(input, 'bravo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    expect(sent, ['alpha', 'bravo']);
    await tester.runAsync(() async {
      second.complete(places('새 마을'));
      await pumpEventQueue();
    });
    await drain(tester);
    expect(find.textContaining('새 마을'), findsOneWidget);
    await tester.runAsync(() async {
      first.complete(places('옛 마을'));
      await pumpEventQueue();
    });
    await drain(tester);
    expect(find.textContaining('새 마을'), findsOneWidget);
    expect(find.textContaining('옛 마을'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
