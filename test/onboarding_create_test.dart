import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/services/notifications.dart';
import 'package:mypet/services/weather.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/onboarding_screen.dart';
import 'package:mypet/ui/shape_picker.dart';

const _notifications = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _paths = MethodChannel('plugins.flutter.io/path_provider');
const _picker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  late Directory folder;
  final errors = <Object>[];
  final delivered = <Pet>[];
  final calls = <String>[];
  Future<Object?> Function(MethodCall)? notificationReply;
  Future<Object?> Function(MethodCall)? pathReply;
  Future<void> Function(Pet)? deliver;

  setUp(() {
    ShapePicker.resetCache();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    errors.clear();
    delivered.clear();
    calls.clear();
    notificationReply = null;
    pathReply = null;
    deliver = null;
    messenger.setMockMethodCallHandler(_notifications, (call) async {
      calls.add(call.method);
      if (call.method == 'getNotificationAppLaunchDetails') {
        return <String, Object>{'notificationLaunchedApp': false};
      }
      if (notificationReply != null) return notificationReply!(call);
      return call.method == 'requestNotificationsPermission' ? false : true;
    });
    messenger.setMockMethodCallHandler(_paths, (call) async {
      if (pathReply != null) return pathReply!(call);
      return folder.path;
    });
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> invoke(WidgetTester tester, VoidCallback action) async {
    await tester.runAsync(() async {
      runZonedGuarded(action, (error, stack) => errors.add(error));
      await pumpEventQueue();
    });
    await drain(tester);
  }

  Future<void> mount(
    WidgetTester tester, {
    bool photo = false,
    bool reminders = false,
    AppDatabase Function()? database,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      db = database?.call() ?? AppDatabase(NativeDatabase.memory());
      folder = await Directory.systemTemp.createTemp('mypet-create-');
      await Notifications.init();
    });
    calls.clear();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
      await tester.runAsync(() async {
        await db.close();
        for (final file in folder.listSync().whereType<File>()) {
          await file.delete();
        }
        await folder.delete();
      });
      for (final channel in [_notifications, _paths, _picker]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: OnboardingScreen(
          db: db,
          weather: WeatherService(
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
          clock: () => DateTime(2026, 10, 20, 15),
          onCreated: (pet) async {
            if (deliver != null) await deliver!(pet);
            delivered.add(pet);
          },
        ),
      ),
    );
    await drain(tester);
    if (photo) {
      final file = await tester.runAsync(() async {
        final image = img.Image(width: 8, height: 8);
        img.fill(image, color: img.ColorRgb8(120, 80, 30));
        return File('${folder.path}/synthetic.png')
          ..writeAsBytesSync(img.encodePng(image));
      });
      messenger.setMockMethodCallHandler(_picker, (_) async => file!.path);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('사진으로 만들기'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      await invoke(tester, button.onPressed!);
    } else {
      await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '합성 친구');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    if (reminders) {
      await tester.tap(find.text('아침·저녁 알림 받기'));
      await tester.pump();
    }
  }

  Future<VoidCallback> start(WidgetTester tester) async => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '건너뛰고 시작'))
      .onPressed!;

  Future<int> count(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.pets).get()))!.length;

  testWidgets('생성 콜백을 연속 호출해도 펫과 권한 요청은 하나다', (tester) async {
    await mount(tester, reminders: true);
    final permission = (await tester.runAsync(() async => Completer<bool>()))!;
    notificationReply = (call) async =>
        call.method == 'requestNotificationsPermission'
        ? permission.future
        : true;
    final action = await start(tester);
    await invoke(tester, action);
    await invoke(tester, action);
    final countWhilePending = await count(tester);
    final requests = calls
        .where((call) => call == 'requestNotificationsPermission')
        .length;
    await tester.runAsync(() async => permission.complete(false));
    await drain(tester);
    expect(countWhilePending, 1);
    expect(requests, 1);
    expect(delivered, hasLength(1));
    expect(errors, isEmpty);
  });

  testWidgets('기본 선택으로 시작하면 알림 요청과 예약 없이 홈에 도착한다', (tester) async {
    await mount(tester);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    await invoke(tester, await start(tester));
    expect(delivered, hasLength(1));
    expect(calls, isEmpty);
  });

  testWidgets('실제 DB 쓰기 실패 뒤 안내하고 같은 입력으로 재시도한다', (tester) async {
    await mount(tester);
    await tester.runAsync(() async {
      await db.customStatement(
        'CREATE TRIGGER fail_create BEFORE INSERT ON pets '
        "BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END",
      );
    });
    await invoke(tester, await start(tester));
    final retry = find.widgetWithText(FilledButton, '건너뛰고 시작');
    expect(errors, isEmpty);
    expect(retry, findsOneWidget);
    expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
    expect(find.text('저장하지 못했어요. 다시 시작해 볼까요?'), findsOneWidget);
    expect(await count(tester), 0);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_create'));
    await invoke(tester, await start(tester));
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
  });

  testWidgets('알림 권한 요청 실패도 저장된 펫의 시작을 막지 않는다', (tester) async {
    await mount(tester, reminders: true);
    notificationReply = (call) async {
      if (call.method == 'requestNotificationsPermission') {
        throw PlatformException(code: 'synthetic-permission');
      }
      return true;
    };
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
    expect(calls, isNot(contains('zonedSchedule')));
  });

  testWidgets('알림 예약 실패도 펫을 다시 저장하지 않고 홈으로 이어간다', (tester) async {
    await mount(tester, reminders: true);
    notificationReply = (call) async {
      if (call.method == 'zonedSchedule') {
        throw PlatformException(code: 'synthetic-schedule');
      }
      return true;
    };
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
    expect(calls.where((call) => call == 'zonedSchedule'), hasLength(1));
  });

  testWidgets('알림 허용은 하루 두 예약 뒤 한 번만 홈으로 이어간다', (tester) async {
    await mount(tester, reminders: true);
    notificationReply = (_) async => true;
    final action = await start(tester);
    await invoke(tester, action);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
    expect(calls.where((call) => call == 'zonedSchedule'), hasLength(2));
    expect(calls.where((call) => call == 'cancelAll'), hasLength(1));
  });

  testWidgets('홈 연결 실패 뒤 재시도해도 같은 펫과 초상화를 재사용한다', (tester) async {
    await mount(tester, photo: true, reminders: true);
    var attempts = 0;
    final ids = <int>[];
    deliver = (pet) async {
      ids.add(pet.id);
      if (++attempts == 1) {
        throw const FileSystemException('synthetic delivery');
      }
    };
    await invoke(tester, await start(tester));
    final pet = (await tester.runAsync(() => db.loadPet()))!;
    final portrait = File(pet.portraitPath!);
    final beforeBytes = portrait.readAsBytesSync();
    expect(find.text('펫은 저장됐어요. 시작을 다시 눌러 주세요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '이전').hitTestable(), findsNothing);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, '동네 이름')).enabled,
      isFalse,
    );
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(ids, [pet.id, pet.id]);
    expect(await count(tester), 1);
    expect(delivered.single.id, pet.id);
    expect(portrait.readAsBytesSync(), beforeBytes);
    expect(folder.listSync().whereType<File>(), hasLength(2));
    expect(
      calls.where((call) => call == 'requestNotificationsPermission'),
      hasLength(1),
    );
  });

  testWidgets('사진 폴더 실패 뒤 기존 파일을 보존하고 다시 시작한다', (tester) async {
    await mount(tester, photo: true);
    final old = File('${folder.path}/portrait.png')
      ..writeAsBytesSync([1, 2, 3]);
    var attempts = 0;
    pathReply = (_) async {
      if (++attempts == 1) throw PlatformException(code: 'synthetic-path');
      return folder.path;
    };
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(await count(tester), 0);
    expect(find.text('저장하지 못했어요. 다시 시작해 볼까요?'), findsOneWidget);
    await invoke(tester, await start(tester));
    final pet = (await tester.runAsync(() => db.loadPet()))!;
    expect(delivered, hasLength(1));
    expect(old.readAsBytesSync(), [1, 2, 3]);
    expect(pet.portraitPath, isNot(old.path));
    expect(img.decodePng(File(pet.portraitPath!).readAsBytesSync())!.width, 64);
  });

  testWidgets('사진 저장 후 DB 실패는 새 파일을 정리하고 재시도한다', (tester) async {
    await mount(tester, photo: true);
    final old = File('${folder.path}/portrait.png')
      ..writeAsBytesSync([1, 2, 3]);
    await tester.runAsync(
      () => db.customStatement(
        'CREATE TRIGGER fail_create BEFORE INSERT ON pets '
        "BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END",
      ),
    );
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(await count(tester), 0);
    expect(folder.listSync().whereType<File>(), hasLength(2));
    expect(old.readAsBytesSync(), [1, 2, 3]);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_create'));
    await invoke(tester, await start(tester));
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
    expect(folder.listSync().whereType<File>(), hasLength(3));
    expect(old.readAsBytesSync(), [1, 2, 3]);
  });

  testWidgets('사진 폴더 응답 전 종료하면 파일과 펫을 만들지 않는다', (tester) async {
    await mount(tester, photo: true);
    final directory = (await tester.runAsync(() async => Completer<String>()))!;
    pathReply = (_) => directory.future;
    final action = await start(tester);
    await invoke(tester, action);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => directory.complete(folder.path));
    await drain(tester);
    await invoke(tester, action);
    expect(errors, isEmpty);
    expect(await count(tester), 0);
    expect(delivered, isEmpty);
    expect(folder.listSync().whereType<File>(), hasLength(1));
    expect(calls, isEmpty);
  });

  testWidgets('알림 권한 응답 전 종료하면 저장한 펫만 유지하고 콜백을 무시한다', (tester) async {
    await mount(tester, reminders: true);
    final permission = (await tester.runAsync(() async => Completer<bool>()))!;
    notificationReply = (call) async =>
        call.method == 'requestNotificationsPermission'
        ? permission.future
        : true;
    await invoke(tester, await start(tester));
    expect(await count(tester), 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => permission.complete(true));
    await drain(tester);
    expect(errors, isEmpty);
    expect(await count(tester), 1);
    expect(delivered, isEmpty);
    expect(calls, ['requestNotificationsPermission']);
    await tester.runAsync(() async {
      final reopenedAt = DateTime(2026, 10, 21, 9);
      expect(await db.eventsOn(DateTime(2026, 10, 20, 15)), isEmpty);
      expect(await db.beginFirstMeeting(reopenedAt), isTrue);
      expect(await db.beginFirstMeeting(reopenedAt), isFalse);
      expect((await db.eventsOn(reopenedAt)).single.kind, 'first_meeting');
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('INSERT 성공 뒤 실패해도 트랜잭션과 새 사진은 함께 복구한다', (tester) async {
    await mount(
      tester,
      photo: true,
      database: () => _CreateDb(failAfterInsert: true),
    );
    await invoke(tester, await start(tester));
    expect(errors, isEmpty);
    expect(await count(tester), 0);
    expect(folder.listSync().whereType<File>(), hasLength(1));
    expect(find.text('저장하지 못했어요. 다시 시작해 볼까요?'), findsOneWidget);
    await invoke(tester, await start(tester));
    expect(await count(tester), 1);
    expect(delivered, hasLength(1));
    expect(File(delivered.single.portraitPath!).existsSync(), isTrue);
    expect(folder.listSync().whereType<File>(), hasLength(2));
  });

  testWidgets('DB 저장 대기 중 종료해도 저장된 펫을 남기고 다음 단계는 중단한다', (tester) async {
    final release = (await tester.runAsync(() async => Completer<void>()))!;
    await mount(tester, database: () => _CreateDb(pause: release.future));
    await invoke(tester, await start(tester));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => release.complete());
    await drain(tester);
    expect(errors, isEmpty);
    expect(await count(tester), 1);
    expect(delivered, isEmpty);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _CreateDb extends AppDatabase {
  _CreateDb({this.pause, this.failAfterInsert = false})
    : super(NativeDatabase.memory());

  final Future<void>? pause;
  bool failAfterInsert;

  @override
  Future<Pet> createPet({
    required String name,
    required PetStage stage,
    required int furMain,
    required int furSecond,
    required int marking,
    required DateTime now,
    String shape = 'papillon',
    String? regionName,
    double? latitude,
    double? longitude,
    String? portraitPath,
  }) async {
    await pause;
    final pet = await super.createPet(
      name: name,
      stage: stage,
      furMain: furMain,
      furSecond: furSecond,
      marking: marking,
      now: now,
      shape: shape,
      regionName: regionName,
      latitude: latitude,
      longitude: longitude,
      portraitPath: portraitPath,
    );
    if (failAfterInsert) {
      failAfterInsert = false;
      throw const FileSystemException('synthetic failure after insert');
    }
    return pet;
  }
}
