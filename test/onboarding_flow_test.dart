import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/services/weather.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/c3/polaroid.dart';
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

  testWidgets('고른 모양·털과 성장 단계가 입양 사진에 보이고 뒤로 가도 이름을 유지한다', (tester) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await tester.pump();
    await tester.tap(find.text('시바·진돗개·스피츠'));
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    final portrait = find.byType(Polaroid);
    PetSpritePreview dog() => tester.widget<PetSpritePreview>(
      find.descendant(of: portrait, matching: find.byType(PetSpritePreview)),
    );
    expect(dog().shape, 'shiba');
    expect(dog().colors.main, furPresets[1].$2);
    expect(dog().stage, PetStage.puppy);
    await drain(tester);
    final paintedDog = find.descendant(
      of: find.descendant(
        of: portrait,
        matching: find.byType(PetSpritePreview),
      ),
      matching: find.byType(CustomPaint),
    );
    final puppyPainter = tester.widget<CustomPaint>(paintedDog).painter!;
    final input = find.widgetWithText(TextField, '이름');
    await tester.enterText(input, '초코');
    await tester.pump();
    expect(tester.widget<Polaroid>(portrait).caption, '초코');
    await tester.tap(find.text('지금 모습 그대로').hitTestable());
    await tester.pump();
    expect(dog().stage, PetStage.adult);
    if (paintedDog.evaluate().isNotEmpty) {
      expect(
        tester
            .widget<CustomPaint>(paintedDog)
            .painter!
            .shouldRepaint(puppyPainter),
        isTrue,
      );
    }
    await drain(tester);
    expect(paintedDog, findsOneWidget);
    await tester.tap(input);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.text('어디에 살아요?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '초코');
    expect(dog().stage, PetStage.adult);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('어떤 아이인가요?'), findsOneWidget);
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).selected,
      'shiba',
    );
  });

  testWidgets('다음으로 간 직후 이전 모양 카드가 이름 화면의 강아지를 바꾸지 않는다', (tester) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await tester.pump();
    final before = tester
        .widget<ShapePicker>(find.byType(ShapePicker))
        .selected;
    tester.semantics.tap(find.semantics.byLabel('다음'));
    tester.semantics.tap(find.semantics.byLabel('시바·진돗개·스피츠'));
    await tester.pumpAndSettle();
    final dog = tester.widget<PetSpritePreview>(
      find.descendant(
        of: find.byType(Polaroid),
        matching: find.byType(PetSpritePreview),
      ),
    );
    expect(dog.shape, before);
  });

  testWidgets('두 배 글씨의 입양 사진에서 긴 이름과 나이가 끝까지 보인다', (tester) async {
    await mount(tester);
    tester.view.physicalSize = const Size(320, 620);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final color = find.widgetWithText(ChoiceChip, '갈색');
    await tester.ensureVisible(color);
    await tester.pumpAndSettle();
    await tester.tap(color);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<PetStage>>(
            find.byType(SegmentedButton<PetStage>),
          )
          .direction,
      Axis.vertical,
    );
    final ageOption = find.text('지금 모습 그대로');
    await tester.ensureVisible(ageOption);
    await tester.pumpAndSettle();
    await tester.tap(ageOption);
    const name = '반짝별무늬강아지';
    await tester.enterText(find.widgetWithText(TextField, '이름'), name);
    await tester.pump();
    final portrait = find.byType(Polaroid);
    await tester.ensureVisible(portrait);
    await tester.pumpAndSettle();
    Finder line(String text) => find.descendant(
      of: portrait,
      matching: find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == text,
      ),
    );
    final nickname = line(name), age = line('다 자란 강아지');
    expect(
      tester.renderObject<RenderParagraph>(nickname).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.getRect(age).top,
      greaterThanOrEqualTo(tester.getRect(nickname).bottom),
    );
    expect(tester.getRect(portrait).contains(tester.getCenter(age)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320폭에서 강아지 모양을 두 개씩 비교하고 키보드로 선택한다', (tester) async {
    await mount(tester);
    tester.view.physicalSize = const Size(320, 620);
    await tester.pumpAndSettle();
    final brown = find.widgetWithText(ChoiceChip, '갈색');
    await tester.ensureVisible(brown);
    await tester.pumpAndSettle();
    await tester.tap(brown.hitTestable());
    await tester.pump();
    Finder option(String name) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == name,
    );
    const firstName = '파피용·치와와';
    const secondName = '말티즈·푸들·비숑·포메';
    final first = option(firstName), second = option(secondName);
    expect(
      tester.getTopLeft(first).dy,
      closeTo(tester.getTopLeft(second).dy, 1),
    );
    expect(tester.getCenter(first).dx, lessThan(tester.getCenter(second).dx));
    await tester.ensureVisible(second);
    await tester.pumpAndSettle();
    final spoken = find.semantics.byLabel(secondName);
    expect(spoken.evaluate(), hasLength(1));
    tester.semantics.performAction(spoken, SemanticsAction.focus);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).selected,
      'maltese',
    );
    expect(tester.widget<Semantics>(second).properties.selected, isTrue);
    expect(
      find.descendant(of: second, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면의 큰 글씨로 모양을 고르고 키보드 위에서 입양 마지막 단계까지 간다', (tester) async {
    await mount(tester);
    tester.view.physicalSize = const Size(320, 520);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final brown = find.widgetWithText(ChoiceChip, '갈색');
    await tester.ensureVisible(brown);
    await tester.pumpAndSettle();
    await tester.tap(brown.hitTestable());
    await tester.pump();
    final card = find.text('시바·진돗개·스피츠');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final spoken = find.semantics.byLabel('시바·진돗개·스피츠');
    expect(spoken.evaluate(), hasLength(1));
    tester.semantics.tap(spoken);
    await tester.pump();
    expect(
      tester.widget<ShapePicker>(find.byType(ShapePicker)).selected,
      'shiba',
    );
    final next = find.widgetWithText(FilledButton, '다음');
    await tester.tap(next.hitTestable());
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, '이름');
    await tester.ensureVisible(name);
    await tester.pumpAndSettle();
    await tester.enterText(name, '몽실이');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(next.hitTestable()).dy,
      lessThanOrEqualTo(260),
    );
    await tester.tap(next.hitTestable());
    await tester.pumpAndSettle();
    final skip = find.widgetWithText(FilledButton, '건너뛰고 시작');
    expect(skip.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(skip).dx, lessThanOrEqualTo(320));
    expect(tester.getBottomRight(skip).dy, lessThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('키보드가 올라온 짧은 화면에서도 다음과 동네 건너뛰기에 닿는다', (tester) async {
    await mount(tester);
    tester.view.physicalSize = const Size(320, 520);
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색').hitTestable());
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '두부');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    final next = find.widgetWithText(FilledButton, '다음').hitTestable();
    expect(tester.getBottomRight(next).dy, lessThanOrEqualTo(240));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('건너뛰고 시작').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('동네를 떠난 뒤 도착한 검색 실패를 이름 화면에 띄우지 않는다', (tester) async {
    final result = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    await mount(tester, client: MockClient((_) => result.future));
    await placePage(tester);
    await tester.enterText(find.widgetWithText(TextField, '동네 이름'), 'alpha');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      result.complete(http.Response('unavailable', 503));
      await pumpEventQueue();
    });
    await drain(tester);
    expect(find.text('이름을 지어 주세요'), findsOneWidget);
    expect(find.text('찾지 못했어요. 시·구 이름으로 다시 해볼까요?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('사진 응답이 이름 화면에 늦게 도착해도 선택한 털색을 유지한다', (tester) async {
    await mount(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await tester.pump();
    final picked = (await tester.runAsync(() async => Completer<String?>()))!;
    messenger.setMockMethodCallHandler(picker, (_) => picked.future);
    final choosePhoto = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('사진으로 만들기'),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        )
        .onPressed!;
    await tester.runAsync(() async {
      choosePhoto();
      await pumpEventQueue();
    });
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      picked.complete(photo.path);
      await pumpEventQueue();
    });
    await drain(tester);
    final dog = tester.widget<PetSpritePreview>(
      find.descendant(
        of: find.byType(Polaroid),
        matching: find.byType(PetSpritePreview),
      ),
    );
    expect(dog.colors.main, furPresets[1].$2);
    expect(find.text('이름을 지어 주세요'), findsOneWidget);
  });

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
    await tester.tap(find.textContaining('고른 마을').hitTestable());
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
    await tester.tap(find.textContaining('새 마을').hitTestable());
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
