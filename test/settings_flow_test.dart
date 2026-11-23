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
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/brain/firebase_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/settings_screen.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/services/telemetry.dart';
import 'package:mypet/ui/shape_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> values;
  Future<void> Function(MethodCall)? beforeStorage;
  late List<String> writes;
  late List<String> deletes;

  setUp(() {
    values = {};
    writes = [];
    deletes = [];
    beforeStorage = null;
    ShapePicker.resetCache();
    messenger.setMockMethodCallHandler(storage, (call) async {
      await beforeStorage?.call(call);
      final args = (call.arguments as Map).cast<String, Object?>();
      final key = args['key'] as String;
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          writes.add(key);
          values[key] = args['value'] as String;
          return null;
        case 'delete':
          deletes.add(key);
          values.remove(key);
          return null;
      }
      throw StateError('Unexpected storage method');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(storage, null));

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> openSettings(
    WidgetTester tester,
    PetController controller, {
    double textScale = 1,
    TestMode? testMode,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SettingsScreen(
          controller: controller,
          onReset: () async {},
          testMode: testMode,
        ),
      ),
    );
    await drain(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '서버 주소'),
      'https://test.invalid/v1',
    );
    await tester.enterText(find.widgetWithText(TextField, '모델'), 'test-model');
    await tester.enterText(
      find.widgetWithText(TextField, '키'),
      'synthetic-key',
    );
  }

  Future<PetController> mount(
    WidgetTester tester, {
    double textScale = 1,
    AppDatabase Function()? database,
  }) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late AppDatabase db;
    final controller = (await tester.runAsync(() async {
      db = database?.call() ?? AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 0xFFB5582E,
        furSecond: 0xFFF5EDE2,
        marking: 0xFF8A3A1A,
        now: DateTime(2026, 10, 20, 12),
      );
      return PetController(db, pet);
    }))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await controller.settled;
        if (!controller.isDisposed) controller.dispose();
        await db.close();
      });
    });
    await openSettings(tester, controller, textScale: textScale);
    return controller;
  }

  http.Response response() => http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({
              'mood_delta': 0,
              'affection_delta': 0,
              'action': 'happy',
              'thought': '반가워!',
              'memory': null,
            }),
          },
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  VoidCallback save(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '저장하고 연결 확인'))
      .onPressed!;

  VoidCallback reset(WidgetTester tester) => tester
      .widget<TextButton>(find.widgetWithText(TextButton, '저장한 설정 지우기'))
      .onPressed!;

  Future<void> start(
    WidgetTester tester,
    VoidCallback callback,
    http.Client client,
    List<Object> errors,
  ) async {
    await tester.runAsync(() async {
      runZonedGuarded(
        () => http.runWithClient(callback, () => client),
        (error, stack) => errors.add(error),
      );
      await pumpEventQueue();
    });
    await tester.pump();
  }

  testWidgets('일반 폰 높이에서 빈 AI 입력 안내는 누른 버튼 곁에 바로 보인다', (tester) async {
    await mount(tester);
    await tester.enterText(find.widgetWithText(TextField, '서버 주소'), '');
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    await tester.pump();
    final button = find.widgetWithText(FilledButton, '저장하고 연결 확인');
    await tester.scrollUntilVisible(
      button,
      240,
      scrollable: find
          .ancestor(of: button, matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final message = find.textContaining('서버 주소, 모델, 키를 모두 넣어 주세요.');
    expect(message, findsOneWidget);
    final rect = tester.getRect(message);
    final controls = tester.getRect(find.text('저장한 설정 지우기'));
    expect(rect.top - controls.bottom, lessThanOrEqualTo(48));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(879));
    expect(writes, isEmpty);
    expect(deletes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final sample in [
    (width: 320.0, height: 640.0, scale: 1.5),
    (width: 360.0, height: 740.0, scale: 2.0),
  ]) {
    testWidgets('작은 화면과 큰 글씨에서도 AI 오류가 보인다: ${sample.width}/${sample.scale}', (
      tester,
    ) async {
      await mount(tester, textScale: sample.scale);
      await tester.enterText(
        find.widgetWithText(TextField, '서버 주소'),
        'http://test.invalid/v1',
      );
      tester.view.physicalSize = Size(sample.width * 3, sample.height * 3);
      tester.view.devicePixelRatio = 3;
      await tester.pump();
      final button = find.widgetWithText(FilledButton, '저장하고 연결 확인');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .ancestor(of: button, matching: find.byType(Scrollable))
            .first,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      final error = find.text('서버 주소는 https://로 시작해야 해요.');
      expect(error, findsOneWidget);
      final rect = tester.getRect(error);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(sample.height));
      expect(
        rect.top - tester.getRect(find.text('저장한 설정 지우기')).bottom,
        lessThanOrEqualTo(48),
      );
      expect(writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('사진·AI·동네 결과는 각 버튼 곁에 남고 서로 덮어쓰지 않는다', (tester) async {
    final c = await mount(tester);
    await tester.enterText(find.widgetWithText(TextField, '서버 주소'), '');
    await tester.tap(find.widgetWithText(FilledButton, '저장하고 연결 확인'));
    await tester.pumpAndSettle();
    final ai = find.textContaining('서버 주소, 모델, 키를 모두 넣어 주세요.');
    expect(ai, findsOneWidget);
    final folder = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mypet-feedback-'),
    ))!;
    final invalid = File('${folder.path}/invalid.png');
    await tester.runAsync(() => invalid.writeAsBytes([1, 2, 3]));
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    messenger.setMockMethodCallHandler(picker, (_) async => invalid.path);
    addTearDown(() async {
      messenger.setMockMethodCallHandler(picker, null);
      await tester.runAsync(() async {
        await invalid.delete();
        await folder.delete();
      });
    });
    await tester.tap(find.text('사진으로 색 다시 뽑기'));
    await drain(tester);
    await tester.pumpAndSettle();
    final photo = find.text('사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
    expect(photo, findsOneWidget);
    expect(ai, findsOneWidget);
    expect(
      tester.getRect(photo).top -
          tester.getRect(find.text('사진으로 색 다시 뽑기')).bottom,
      lessThanOrEqualTo(48),
    );
    await tester.tap(find.text('동네 넣기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '관악구',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await drain(tester);
    final places = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ListTile),
    );
    expect(places, findsOneWidget);
    await tester.tap(places);
    await drain(tester);
    await tester.pumpAndSettle();
    final region = find.textContaining('날씨를 봐요.');
    expect(region, findsOneWidget);
    expect(ai, findsOneWidget);
    expect(photo, findsOneWidget);
    expect(c.pet.regionName, '관악구');
    expect(
      tester.getRect(region).top - tester.getRect(find.text('동네 바꾸기')).bottom,
      lessThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 응답을 기다리며 맨 아래로 내려가도 결과가 완료되면 바로 보인다', (tester) async {
    final c = await mount(tester);
    await openSettings(
      tester,
      c,
      testMode: TestMode(File('unused-feedback-mode.json')),
      textScale: 2,
    );
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    await tester.pump();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '저장하고 연결 확인'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final reply = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    final errors = <Object>[];
    await start(tester, save(tester), MockClient((_) => reply.future), errors);
    final scrollable = find
        .ancestor(
          of: find.widgetWithText(FilledButton, '확인 중…'),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var i = 0; i < 4; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    await tester.runAsync(() async {
      reply.complete(response());
      await pumpEventQueue();
    });
    await drain(tester);
    await tester.pumpAndSettle();
    expect(errors, isEmpty);
    final message = find.textContaining('연결됐어요.');
    expect(message, findsOneWidget);
    final rect = tester.getRect(message);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 선택 대기 중 설정과 펫을 닫으면 늦은 정상 사진은 적용하지 않는다', (tester) async {
    final c = await mount(tester);
    final previous = c.pet;
    final folder = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mypet-photo-lifetime-'),
    ))!;
    final photo = File('${folder.path}/selected.png');
    await tester.runAsync(
      () => photo.writeAsBytes(img.encodePng(img.Image(width: 8, height: 8))),
    );
    final picked = (await tester.runAsync(() async => Completer<String?>()))!;
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(picker, (_) => picked.future);
    messenger.setMockMethodCallHandler(paths, (_) async => folder.path);
    addTearDown(() async {
      messenger.setMockMethodCallHandler(picker, null);
      messenger.setMockMethodCallHandler(paths, null);
      await tester.runAsync(() async {
        for (final file in folder.listSync().whereType<File>()) {
          await file.delete();
        }
        await folder.delete();
      });
    });
    final errors = <Object>[];
    final choose = tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '사진으로 색 다시 뽑기'),
        )
        .onPressed!;
    await start(tester, choose, MockClient((_) async => response()), errors);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(() async {
      picked.complete(photo.path);
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.pet.portraitPath, previous.portraitPath);
    expect((await tester.runAsync(() async => folder.listSync().length)), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 폴더 대기 중 닫으면 기존 초상화를 지키고 새 화면에서 다시 바꿀 수 있다', (tester) async {
    final c = await mount(tester);
    final folder = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mypet-photo-save-'),
    ))!;
    final old = File('${folder.path}/portrait.png');
    final selected = File('${folder.path}/selected.png');
    final originalBytes = img.encodePng(img.Image(width: 8, height: 8));
    await tester.runAsync(() async {
      await old.writeAsBytes(originalBytes);
      await selected.writeAsBytes(originalBytes);
    });
    final docs = (await tester.runAsync(() async => Completer<String>()))!;
    final requested = (await tester.runAsync(() async => Completer<void>()))!;
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    var first = true;
    messenger.setMockMethodCallHandler(picker, (_) async => selected.path);
    messenger.setMockMethodCallHandler(paths, (_) async {
      if (first) {
        first = false;
        requested.complete();
        return docs.future;
      }
      return folder.path;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(picker, null);
      messenger.setMockMethodCallHandler(paths, null);
      await tester.runAsync(() async {
        for (final file in folder.listSync().whereType<File>()) {
          await file.delete();
        }
        await folder.delete();
      });
    });
    final errors = <Object>[];
    VoidCallback choose() => tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '사진으로 색 다시 뽑기'),
        )
        .onPressed!;
    await start(tester, choose(), MockClient((_) async => response()), errors);
    await tester.runAsync(
      () => requested.future.timeout(const Duration(seconds: 2)),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      docs.complete(folder.path);
      await pumpEventQueue();
    });
    await drain(tester);
    expect(c.pet.portraitPath, isNull);
    expect((await tester.runAsync(() => old.readAsBytes())), originalBytes);
    expect((await tester.runAsync(() async => folder.listSync().length)), 2);
    await openSettings(tester, c);
    await start(tester, choose(), MockClient((_) async => response()), errors);
    for (var i = 0; i < 20 && c.pet.portraitPath == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await drain(tester);
    await tester.pumpAndSettle();
    expect(errors, isEmpty);
    expect(c.pet.portraitPath, isNotNull);
    expect(c.pet.portraitPath, isNot(old.path));
    expect((await tester.runAsync(() => old.readAsBytes())), originalBytes);
    expect(find.text('사진에서 뽑은 색으로 다시 칠했어요.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '사진으로 색 다시 뽑기'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 쓰기만 거절되면 기존 외모가 남고 같은 얼굴을 다시 눌러 저장한다', (tester) async {
    late AppDatabase db;
    final c = await mount(
      tester,
      database: () => db = AppDatabase(NativeDatabase.memory()),
    );
    final previous = c.pet;
    final folder = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mypet-retry-portrait-'),
    ))!;
    const picker = MethodChannel('plugins.flutter.io/image_picker');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    var picks = 0;
    final source = File(
      'tools/scene_preview/fixtures/synthetic-beagle.jpg',
    ).absolute;
    messenger.setMockMethodCallHandler(picker, (_) async {
      picks++;
      return source.path;
    });
    messenger.setMockMethodCallHandler(paths, (_) async => folder.path);
    addTearDown(() async {
      messenger.setMockMethodCallHandler(picker, null);
      messenger.setMockMethodCallHandler(paths, null);
      await tester.runAsync(() => folder.delete(recursive: true));
    });
    await tester.runAsync(
      () => db.customStatement(
        "CREATE TRIGGER reject_image BEFORE UPDATE OF portrait_path ON pets BEGIN SELECT RAISE(ABORT, 'qa'); END",
      ),
    );
    Future<void> awaitCondition(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 8)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(done(), isTrue);
    }

    await tester.runAsync(() => tester.tap(find.text('사진으로 색 다시 뽑기')));
    final retry = find.text('이 얼굴 다시 저장');
    await awaitCondition(() => retry.hitTestable().evaluate().isNotEmpty);
    await drain(tester);
    expect(c.pet.furMain, previous.furMain);
    expect(c.pet.portraitPath, previous.portraitPath);
    await tester.runAsync(() async {
      expect((await db.loadPet())!.portraitPath, previous.portraitPath);
      expect(folder.listSync().whereType<File>(), isEmpty);
      expect(await source.exists(), isTrue);
      await db.customStatement('DROP TRIGGER reject_image');
    });
    await tester.runAsync(() => tester.tap(retry.hitTestable()));
    await awaitCondition(
      () => c.pet.portraitPath != null && retry.evaluate().isEmpty,
    );
    expect(picks, 1);
    await tester.runAsync(() async {
      final stored = (await db.loadPet())!;
      expect(stored.furMain, c.pet.furMain);
      expect(stored.portraitPath, c.pet.portraitPath);
      expect(
        img.decodePng(await File(stored.portraitPath!).readAsBytes())!.width,
        64,
      );
      expect(folder.listSync().whereType<File>(), hasLength(1));
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI 확인 중 설정을 닫으면 늦은 성공이 해제된 입력칸이나 이전 펫을 건드리지 않는다', (
    tester,
  ) async {
    final c = await mount(tester);
    final previous = c.brain;
    final reply = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    final errors = <Object>[];
    var requests = 0;
    await start(
      tester,
      save(tester),
      MockClient((_) {
        requests++;
        return reply.future;
      }),
      errors,
    );
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      reply.complete(response());
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, same(previous));
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('열린 설정에서 AI 확인이 성공하면 설정을 저장하고 연결을 바꾼다', (tester) async {
    final c = await mount(tester);
    final errors = <Object>[];
    await start(
      tester,
      save(tester),
      MockClient((_) async => response()),
      errors,
    );
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, isA<AiBrain>());
    expect(values['ai_url'], 'https://test.invalid/v1');
    expect(values['ai_model'], 'test-model');
    expect(values['ai_key'], 'synthetic-key');
    expect(writes, ['ai_url', 'ai_model', 'ai_key']);
    expect(find.textContaining('연결됐어요.'), findsOneWidget);
  });

  testWidgets('AI 확인 실패가 늦게 와도 닫힌 설정을 갱신하지 않는다', (tester) async {
    final c = await mount(tester);
    final reply = (await tester.runAsync(
      () async => Completer<http.Response>(),
    ))!;
    final errors = <Object>[];
    await start(tester, save(tester), MockClient((_) => reply.future), errors);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      reply.complete(http.Response('unavailable', 503));
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, isNull);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정만 닫아도 삭제가 완료되면 살아 있는 홈의 AI를 기본으로 바꾼다', (tester) async {
    final c = await mount(tester);
    final previous = AiBrain(
      baseUrl: 'https://old.invalid/v1',
      model: 'old-model',
      apiKey: 'old-synthetic',
      client: MockClient((_) async => response()),
    );
    c.brain = previous;
    values.addAll({
      'ai_url': 'https://old.invalid/v1',
      'ai_model': 'old-model',
      'ai_key': 'old-synthetic',
    });
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    beforeStorage = (call) async {
      if (call.method == 'delete') await release.future;
    };
    final errors = <Object>[];
    await start(
      tester,
      reset(tester),
      MockClient((_) async => response()),
      errors,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      release.complete();
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, isA<FirebaseBrain>());
    expect(values, isEmpty);
    expect(deletes, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정 삭제 실패는 현재 연결을 유지하고 다음 삭제를 다시 허용한다', (tester) async {
    final c = await mount(tester);
    final previous = AiBrain(
      baseUrl: 'https://old.invalid/v1',
      model: 'old-model',
      apiKey: 'old-synthetic',
      client: MockClient((_) async => response()),
    );
    c.brain = previous;
    var fail = true;
    beforeStorage = (call) async {
      if (call.method == 'delete' && fail) {
        throw PlatformException(code: 'test-storage-failure');
      }
    };
    final errors = <Object>[];
    final client = MockClient((_) async => response());
    await start(tester, reset(tester), client, errors);
    await drain(tester);
    expect(c.brain, same(previous));
    expect(find.textContaining('설정을 지우지 못했어요:'), findsOneWidget);
    fail = false;
    await start(tester, reset(tester), client, errors);
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, isNot(same(previous)));
    expect(deletes, hasLength(4));
    expect(find.textContaining('기본 AI(Google Gemini)로 돌아갔어요.'), findsOneWidget);
  });

  testWidgets('연결 확인 기록은 실패 원문·서버 주소·모델·키를 포함하지 않는다', (tester) async {
    await mount(tester);
    final errors = <Object>[];
    final events = <(String, Map<String, Object>)>[];
    await Telemetry.captureEvents(
      (name, params) => events.add((name, params)),
      () => start(
        tester,
        save(tester),
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'SYNTHETIC_PRIVATE_SERVER_ERROR'},
            }),
            401,
          ),
        ),
        errors,
      ),
    );
    await drain(tester);
    expect(events.where((e) => e.$1 == 'ai_check').single.$2, {
      'ok': 0,
      'provider': 'custom',
      'error': 'http_401',
    });
    expect(
      find.textContaining('SYNTHETIC_PRIVATE_SERVER_ERROR'),
      findsOneWidget,
    );
    expect(writes, isEmpty);
    events.clear();
    await Telemetry.captureEvents(
      (name, params) => events.add((name, params)),
      () => start(
        tester,
        save(tester),
        MockClient((_) async => response()),
        errors,
      ),
    );
    await drain(tester);
    expect(events.where((e) => e.$1 == 'ai_check').single.$2, {
      'ok': 1,
      'provider': 'custom',
    });
    expect(values['ai_key'], 'synthetic-key');
    expect(errors, isEmpty);
  });

  testWidgets('연결 확인 실패 뒤 입력을 고쳐 다시 저장할 수 있다', (tester) async {
    final c = await mount(tester);
    final errors = <Object>[];
    await start(
      tester,
      save(tester),
      MockClient((_) async => http.Response('unavailable', 503)),
      errors,
    );
    await drain(tester);
    expect(c.brain, isNull);
    expect(writes, isEmpty);
    expect(find.textContaining('연결 실패:'), findsOneWidget);
    await start(
      tester,
      save(tester),
      MockClient((_) async => response()),
      errors,
    );
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, isA<AiBrain>());
    expect(values['ai_key'], 'synthetic-key');
  });

  testWidgets('설정을 다시 열어 저장해도 이전 화면의 늦은 삭제가 새 설정을 지우지 않는다', (tester) async {
    final current = await mount(tester);
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    var firstDelete = true;
    beforeStorage = (call) async {
      if (call.method == 'delete' && firstDelete) {
        firstDelete = false;
        await release.future;
      }
    };
    final errors = <Object>[];
    final client = MockClient((_) async => response());
    await start(tester, reset(tester), client, errors);
    await tester.pumpWidget(const SizedBox());
    await openSettings(tester, current);
    await start(tester, save(tester), client, errors);
    await drain(tester);
    final writesWhileDeleting = writes.length;
    await tester.runAsync(() async {
      release.complete();
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(values['ai_url'], 'https://test.invalid/v1');
    expect(values['ai_model'], 'test-model');
    expect(values['ai_key'], 'synthetic-key');
    expect(current.brain, isA<AiBrain>());
    expect(writesWhileDeleting, 0);
  });

  testWidgets('저장 중 설정을 다시 열어 삭제하면 늦은 저장이 삭제 결과를 덮지 않는다', (tester) async {
    final c = await mount(tester);
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    var firstWrite = true;
    beforeStorage = (call) async {
      if (call.method == 'write' && firstWrite) {
        firstWrite = false;
        await release.future;
      }
    };
    final errors = <Object>[];
    final client = MockClient((_) async => response());
    await start(tester, save(tester), client, errors);
    await tester.pumpWidget(const SizedBox());
    await openSettings(tester, c);
    await start(tester, reset(tester), client, errors);
    final deletesWhileWriting = deletes.length;
    await tester.runAsync(() async {
      release.complete();
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(deletesWhileWriting, 0);
    expect(values, isEmpty);
    expect(c.brain, isA<FirebaseBrain>());
    expect(find.textContaining('기본 AI(Google Gemini)로 돌아갔어요.'), findsOneWidget);
  });

  testWidgets('삭제 응답을 기다리다 펫 컨트롤러까지 해제되면 옛 연결을 바꾸지 않는다', (tester) async {
    final c = await mount(tester);
    final previous = c.brain;
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    beforeStorage = (call) async {
      if (call.method == 'delete') await release.future;
    };
    final errors = <Object>[];
    await start(
      tester,
      reset(tester),
      MockClient((_) async => response()),
      errors,
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(() async {
      release.complete();
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(c.brain, same(previous));
    expect(deletes, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정 삭제 대기 중에는 새 연결 확인이나 중복 삭제가 끼어들지 않는다', (tester) async {
    await mount(tester);
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    var deleteStarts = 0;
    beforeStorage = (call) async {
      if (call.method == 'delete') {
        deleteStarts++;
        await release.future;
      }
    };
    final staleSave = save(tester);
    final staleReset = reset(tester);
    final errors = <Object>[];
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return response();
    });
    await start(tester, staleReset, client, errors);
    await start(tester, staleSave, client, errors);
    await start(tester, staleReset, client, errors);
    final startsWhileWaiting = deleteStarts;
    await tester.runAsync(() async {
      release.complete();
      await pumpEventQueue();
    });
    await drain(tester);
    expect(errors, isEmpty);
    expect(startsWhileWaiting, 1);
    expect(requests, 0);
    expect(deletes, ['ai_url', 'ai_model', 'ai_key', 'groq_api_key']);
    expect(writes, isEmpty);
    expect(find.text('저장하고 연결 확인'), findsOneWidget);
  });
}
