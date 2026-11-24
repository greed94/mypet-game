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
import 'package:mypet/ui/memory_notebook.dart';
import 'package:mypet/ui/time_sheet.dart';

class _DelayedModeFile implements File {
  _DelayedModeFile(this.file);
  final File file;
  File get staging => File('${file.path}.next');
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
      if (failFirst) {
        await staging.writeAsString('{', flush: true);
        throw FileSystemException('Synthetic partial write');
      }
    }
    return staging.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  @override
  Future<File> rename(String newPath) => staging.rename(newPath);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CloseFailureDatabase extends AppDatabase {
  _CloseFailureDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> close() async {
    await super.close();
    throw StateError('Synthetic previous connection close failure');
  }
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

  Future<_Session> mount(
    WidgetTester tester, {
    Duration savedOffset = Duration.zero,
    bool failPreviousClose = false,
  }) async {
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
      final db = failPreviousClose
          ? _CloseFailureDatabase()
          : AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: base,
      );
      final file = _DelayedModeFile(File('${dir.path}/test_mode.json'));
      await file.file.writeAsString(
        jsonEncode({'on': true, 'offsetMinutes': savedOffset.inMinutes}),
      );
      return (
        db,
        pet,
        TestMode(file.file, on: true, offset: savedOffset, stagingFile: file),
        file,
      );
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

  testWidgets('작은 화면에서 시트를 열어 둔 사이 05시가 지나면 누른 때의 다음 아침으로 간다', (tester) async {
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = DateTime(2026, 11, 24, 4, 59);
    Duration? chosen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                chosen = await showTimeSheet(context, () => now);
              },
              child: const Text('연습 시계'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('연습 시계'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    now = DateTime(2026, 11, 24, 5, 1);
    await tester.ensureVisible(find.text('다음 날 아침 9시'));
    await tester.tap(find.text('다음 날 아침 9시'));
    await tester.pumpAndSettle();
    expect(now.add(chosen!), DateTime(2026, 11, 25, 9));
  });

  testWidgets('첫 끼를 준 연습 펫과 다음 날 아침에 만나고 같은 기억은 한 번만 남긴다', (tester) async {
    final session = await mount(tester);
    final c = session.home.controller;
    final db = session.home.db;
    final first = c.now();
    await tester.runAsync(() async {
      await db.queueFirstMeeting(first);
      await db.beginFirstMeeting(first);
      c.interact(Interaction.feed);
      await c.settled;
    });
    session.file.release.complete();
    await tester.tap(find.text('시간 보내기 ›'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => tester.tap(find.text('다음 날 아침 9시')));
    await tester.pump();
    for (var i = 0; i < 100 && session.mode.offset == Duration.zero; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await c.settled;
      expect(c.now(), DateTime(first.year, first.month, first.day + 1, 9));
      c.interact(Interaction.pet);
      await c.settled;
      expect(c.bubble, contains('밥 주던 손'));
      c.interact(Interaction.pet);
      await c.settled;
      expect(await db.eventsOfKind('first_recognition'), hasLength(1));
      expect(await db.allDiaries(), hasLength(1));
    });
  });

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

  testWidgets('이미 보여 준 재회를 저장하기 전에는 현재 펫을 지키고 저장 후 전환한다', (tester) async {
    final session = await mount(tester, savedOffset: const Duration(days: 1));
    final old = session.home.controller;
    final db = session.home.db;
    await tester.runAsync(() async {
      await old.settled;
      final met = old.pet.bornAt;
      await db.queueFirstMeeting(met);
      await db.beginFirstMeeting(met);
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db.customStatement(
        'CREATE TABLE synthetic_parent (id INTEGER PRIMARY KEY)',
      );
      await db.customStatement(
        'CREATE TABLE synthetic_child (parent_id INTEGER REFERENCES synthetic_parent(id) DEFERRABLE INITIALLY DEFERRED)',
      );
      await db.customStatement(
        """CREATE TRIGGER fail_commit AFTER INSERT ON events
        WHEN NEW.kind='first_recognition' BEGIN INSERT INTO synthetic_child VALUES(1); END""",
      );
      old.interact(Interaction.pet);
      await old.settled;
      expect(old.bubble, '이 냄새, 어제 처음 맡아 봤어.');
      expect(await db.eventsOfKind('first_recognition'), isEmpty);
      await session.leave();
    });
    await tester.pump();
    expect(session.mode.on, isTrue);
    expect(old.isDisposed, isFalse);
    expect(
      find.text('재회 기록을 저장하지 못해 지금 펫을 열어 뒀어요. 다시 시도해 주세요.'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await db.customStatement('DROP TRIGGER fail_commit');
      session.file.release.complete();
      await session.leave();
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.mode.on, isFalse);
    expect(old.isDisposed, isTrue);
    expect(
      await tester.runAsync(
        () => session.active.db.eventsOfKind('first_recognition'),
      ),
      isEmpty,
    );
  });

  testWidgets('연습 펫의 미저장 산책이 남으면 지키고 복구한 뒤에만 실제 펫으로 전환한다', (tester) async {
    final session = await mount(tester);
    final old = session.home.controller;
    await tester.runAsync(() async {
      await old.settled;
      await session.home.db.customStatement(
        "CREATE TRIGGER pending_walk BEFORE INSERT ON events WHEN NEW.kind='walk' BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      expect(old.startWalk(), isTrue);
      old.endWalk();
      expect(await old.lastWalkRecord!.saved, isFalse);
      await session.leave();
    });
    await tester.pump();
    expect(session.mode.on, isTrue);
    expect(old.isDisposed, isFalse);
    expect(old.unsavedWalkCount, 1);
    expect(find.text('다시 저장').hitTestable(), findsOneWidget);
    await tester.runAsync(() async {
      await session.home.db.customStatement('DROP TRIGGER pending_walk');
      session.file.release.complete();
      await session.leave();
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.mode.on, isFalse);
    expect(old.isDisposed, isTrue);
    expect(find.text('다시 저장'), findsNothing);
    expect(
      await tester.runAsync(() => session.active.db.eventsOfKind('walk')),
      isEmpty,
    );
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

  testWidgets('전환 중에는 이전 수첩과 삭제 확인을 닫고 홈 입력을 가린다', (tester) async {
    final session = await mount(tester);
    final old = session.home.controller;
    final memory = (await tester.runAsync(() async {
      await session.home.db.addMemory('연습 수첩 합성 항목', DateTime(2026, 11, 20));
      return (await session.home.db.recentMemories(1)).single;
    }))!;
    await tester.tap(find.text('도감').hitTestable());
    await tester.pump();
    await tester.tap(find.text('기억 수첩').hitTestable());
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 35));
    }
    await tester.tap(find.byTooltip('기억 지우기'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('이 기억을 지울까요?'), findsOneWidget);
    late Future<void> leaving;
    await tester.runAsync(() async {
      leaving = session.leave();
      await session.file.started.future;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('펫을 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(MemoryNotebook).hitTestable(), findsNothing);
    expect(find.text('이 기억을 지울까요?').hitTestable(), findsNothing);
    expect(find.text('기억 수첩').hitTestable(), findsNothing);
    expect(old.isResetting, isTrue);
    expect(await tester.runAsync(() => old.forgetMemory(memory.id)), isFalse);
    expect(
      (await tester.runAsync(
        () => session.home.db.recentMemories(1),
      ))!.single.id,
      memory.id,
    );
    await tester.runAsync(() async {
      session.file.release.complete();
      await leaving;
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(old.isDisposed, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(MemoryNotebook), findsNothing);
    expect(find.text('이 기억을 지울까요?'), findsNothing);
    expect(
      await tester.runAsync(() => session.active.db.recentMemories(1)),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('모드 파일 저장 실패는 연습 펫과 앞선 시계를 보존하고 다시 전환할 수 있다', (tester) async {
    final session = await mount(tester, savedOffset: const Duration(hours: 3));
    session.file.failFirst = true;
    final old = session.home.controller;
    await tester.runAsync(() async {
      final first = session.leave();
      await session.file.started.future;
      session.file.release.complete();
      await first;
    });
    await tester.pump();
    expect(find.text('펫을 바꾸지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(session.mode.on, isTrue);
    expect(session.mode.offset, const Duration(hours: 3));
    final reopened = (await tester.runAsync(
      () => TestMode.load(session.file.file),
    ))!;
    expect(reopened.on, isTrue);
    expect(reopened.offset, const Duration(hours: 3));
    expect(old.isResetting, isFalse);
    expect(old.isDisposed, isFalse);
    await tester.runAsync(session.leave);
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.mode.on, isFalse);
    expect(session.active.controller, isNot(same(old)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('이전 연결 정리가 실패해도 이미 돌아온 실제 펫에 전환 실패 안내가 뜨지 않는다', (tester) async {
    final session = await mount(tester, failPreviousClose: true);
    await tester.runAsync(() async {
      final leaving = session.leave();
      await session.file.started.future;
      session.file.release.complete();
      await leaving;
    });
    await tester.pump();
    session.active = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(session.active.controller, isNot(same(session.home.controller)));
    expect(
      (await tester.runAsync(() => TestMode.load(session.file.file)))!.on,
      isFalse,
    );
    expect(find.text('펫을 바꾸지 못했어요. 다시 시도해 주세요.'), findsNothing);
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
