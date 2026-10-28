import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/pet_game.dart';
import 'package:mypet/main.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/ui/home_screen.dart';

class _DelayedModeFile implements File {
  _DelayedModeFile(this.file);
  final File file;
  final started = Completer<void>();
  final release = Completer<void>();
  final writes = <Map<String, dynamic>>[];
  bool failFirst = false;

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    writes.add(jsonDecode(contents) as Map<String, dynamic>);
    if (writes.length == 1) {
      started.complete();
      await release.future;
      if (failFirst) throw FileSystemException('Synthetic write failure');
    }
    return file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session {
  _Session(this.mode, this.file, this.home) : active = home;
  final TestMode mode;
  final _DelayedModeFile file;
  final HomeScreen home;
  HomeScreen active;
  final operations = <Future<void>>[];

  Future<void> jump(Duration duration) {
    final result = home.onJump!(duration);
    operations.add(result.then((_) {}, onError: (_) {}));
    return result;
  }

  Future<void> leave() {
    final result = home.onTestMode!(false);
    operations.add(result.then((_) {}, onError: (_) {}));
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const provider = MethodChannel('plugins.flutter.io/path_provider');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<_Session> mount(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('mypet_time_flow_');
    addTearDown(() => dir.deleteSync(recursive: true));
    FlutterSecureStorage.setMockInitialValues({'steps_asked': 'true'});
    messenger.setMockMethodCallHandler(provider, (_) async => dir.path);
    messenger.setMockMethodCallHandler(permissions, (_) async => 0);
    addTearDown(() {
      messenger.setMockMethodCallHandler(provider, null);
      messenger.setMockMethodCallHandler(permissions, null);
    });
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final base = DateTime(2026, 10, 20, 10);
    final prepared = (await tester.runAsync(() async {
      final real = AppDatabase(NativeDatabase.memory());
      await real.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: base,
      );
      await real.customStatement('VACUUM INTO ?', ['${dir.path}/mypet.sqlite']);
      await real.close();
      final db = AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: base,
      );
      final file = _DelayedModeFile(File('${dir.path}/test_mode.json'));
      return (db, pet, TestMode(file, on: true), file);
    }))!;
    final (db, pet, mode, file) = prepared;
    await tester.runAsync(
      () => tester.pumpWidget(
        MypetApp(
          db: db,
          initialPet: pet,
          systemPrompt: '',
          diaryPrompt: '',
          ai: null,
          clock: () => base.add(mode.offset),
          testMode: mode,
          docs: dir.path,
        ),
      ),
    );
    final session = _Session(
      mode,
      file,
      tester.widget<HomeScreen>(find.byType(HomeScreen)),
    );
    tester
        .widget<GameWidget<PetGame>>(find.byType(GameWidget<PetGame>))
        .game!
        .pauseEngine();
    addTearDown(() async {
      await tester.runAsync(() async {
        if (!file.release.isCompleted) file.release.complete();
        await Future.wait(
          session.operations.map((f) => f.then((_) {}, onError: (_) {})),
        );
        final active = session.active;
        await tester.pumpWidget(const SizedBox());
        await active.controller.settled;
        active.controller.dispose();
        await active.db.customSelect('SELECT 1').get();
        await active.db.close();
        await pumpEventQueue();
      });
    });
    await tester.runAsync(() => session.home.controller.settled);
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    return session;
  }

  testWidgets('시간 저장 중 두 번째 시간 보내기는 첫 시계를 덮어쓰지 않는다', (tester) async {
    final session = await mount(tester);
    var writesWhilePending = 0;
    await tester.runAsync(() async {
      final first = session.jump(const Duration(hours: 1));
      await session.file.started.future;
      await session.jump(const Duration(hours: 2));
      writesWhilePending = session.file.writes.length;
      session.file.release.complete();
      await first;
      await session.home.controller.settled;
    });
    expect(writesWhilePending, 1);
    expect(session.mode.offset, const Duration(hours: 1));
    final saved = await tester.runAsync(() => TestMode.load(session.file.file));
    expect(saved!.offset, session.mode.offset);
  });

  testWidgets('연습 종료는 대기 중인 시간 저장과 깨우기가 끝난 뒤 실제 펫으로 바꾼다', (tester) async {
    final session = await mount(tester);
    final old = session.home.controller;
    var switchedEarly = false;
    var writesWhilePending = 0;
    await tester.runAsync(() async {
      final jump = session.jump(const Duration(hours: 1));
      await session.file.started.future;
      final leave = session.leave().then((_) => switchedEarly = true);
      await pumpEventQueue();
      writesWhilePending = session.file.writes.length;
      final early = switchedEarly;
      session.file.release.complete();
      await Future.wait([jump, leave]);
      expect(early, isFalse);
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    final active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(writesWhilePending, 1);
    expect(active.controller, isNot(same(old)));
    expect(session.mode.on, isFalse);
    expect(session.mode.offset, Duration.zero);
    final saved = await tester.runAsync(() => TestMode.load(session.file.file));
    expect(saved!.on, isFalse);
    expect(saved.offset, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연습 종료가 시작된 뒤 이전 홈의 시간 보내기는 실제 펫 시계를 바꾸지 않는다', (tester) async {
    final session = await mount(tester);
    await tester.runAsync(() async {
      final leaving = session.leave();
      final jumping = session.jump(const Duration(hours: 2));
      await session.file.started.future;
      session.file.release.complete();
      await Future.wait([leaving, jumping]);
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.file.writes, hasLength(1));
    expect(session.file.writes.single['on'], isFalse);
    expect(session.mode.on, isFalse);
    expect(session.mode.offset, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시간 저장 실패 후에도 다시 시간을 보내고 연습 모드를 종료할 수 있다', (tester) async {
    final session = await mount(tester);
    session.file.failFirst = true;
    await tester.runAsync(() async {
      final first = session.jump(const Duration(hours: 1));
      Object? failure;
      final failed = first.then(
        (_) {},
        onError: (Object error) {
          failure = error;
        },
      );
      await session.file.started.future;
      session.file.release.complete();
      await failed;
      expect(failure, isA<FileSystemException>());
      expect(session.mode.offset, Duration.zero);
      await session.jump(const Duration(hours: 2));
      expect(session.mode.offset, const Duration(hours: 2));
      await session.leave();
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.mode.on, isFalse);
    expect(session.mode.offset, Duration.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시간 저장 실패를 기다리던 연습 종료도 멈추지 않고 실제 펫으로 돌아간다', (tester) async {
    final session = await mount(tester);
    session.file.failFirst = true;
    await tester.runAsync(() async {
      final first = session.jump(const Duration(hours: 1));
      Object? failure;
      final failed = first.then(
        (_) {},
        onError: (Object error) {
          failure = error;
        },
      );
      await session.file.started.future;
      final leaving = session.leave();
      await pumpEventQueue();
      session.file.release.complete();
      await failed;
      expect(failure, isA<FileSystemException>());
      await leaving;
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.mode.on, isFalse);
    expect(session.mode.offset, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
