import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/pet_game.dart';
import 'package:mypet/main.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/ui/home_screen.dart';
import 'package:mypet/ui/onboarding_screen.dart';

class _ResetDb extends AppDatabase {
  _ResetDb() : super(NativeDatabase.memory());
  Completer<void>? resetGate;
  int resets = 0;
  Completer<void>? receiveGate;

  @override
  Future<void> removeCarried(int id) async {
    await receiveGate?.future;
    await super.removeCarried(id);
  }

  @override
  Future<void> resetAll() async {
    resets++;
    await resetGate?.future;
    await super.resetAll();
  }
}

class _HeldBrain implements PetBrain {
  final gate = Completer<void>();
  final talkStarted = Completer<void>();
  final diaryStarted = Completer<void>();

  @override
  String get label => '합성 지연';

  @override
  Future<PetDecision> decide(String system, String user) async {
    talkStarted.complete();
    await gate.future;
    return const PetDecision(
      moodDelta: 0,
      affectionDelta: 0,
      action: PetAction.sit,
      thought: '왔구나.',
      memory: '이전 검사펫의 기억',
    );
  }

  @override
  Future<String> writeText(String system, String user) async {
    diaryStarted.complete();
    await gate.future;
    return '이전 검사펫의 하루였다.';
  }
}

class _Session {
  _Session(this.db, this.home, this.now);
  final _ResetDb db;
  final HomeScreen home;
  final DateTime now;
  final operations = <Future<void>>[];
  final errors = <Object>[];
  _HeldBrain? brain;

  void startReset() {
    operations.add(home.onReset().catchError((Object e) => errors.add(e)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  bool notificationFails = false;

  Future<_Session> mount(WidgetTester tester) async {
    notificationFails = false;
    FlutterSecureStorage.setMockInitialValues({'steps_asked': 'true'});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final dir = Directory.systemTemp.createTempSync('mypet_reset_flow_');
    messenger.setMockMethodCallHandler(paths, (_) async => dir.path);
    messenger.setMockMethodCallHandler(permissions, (_) async => 0);
    messenger.setMockMethodCallHandler(notifications, (_) async {
      if (notificationFails) throw PlatformException(code: 'synthetic');
      return true;
    });
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 10, 28, 12);
    final prepared = (await tester.runAsync(() async {
      final db = _ResetDb();
      final pet = await db.createPet(
        name: '검사펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now,
      );
      return (db, pet);
    }))!;
    final (db, pet) = prepared;
    await tester.runAsync(
      () => tester.pumpWidget(
        MypetApp(
          db: db,
          initialPet: pet,
          systemPrompt: '',
          diaryPrompt: '',
          ai: null,
          clock: () => now,
          testMode: TestMode(File('${dir.path}/mode.json')),
          docs: dir.path,
        ),
      ),
    );
    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    final session = _Session(db, home, now);
    tester
        .widget<GameWidget<PetGame>>(find.byType(GameWidget<PetGame>))
        .game!
        .pauseEngine();
    await tester.runAsync(() => home.controller.settled);
    await tester.pump();
    addTearDown(() async {
      await tester.runAsync(() async {
        if (db.resetGate case final gate? when !gate.isCompleted) {
          gate.complete();
        }
        if (session.brain case final b? when !b.gate.isCompleted) {
          b.gate.complete();
        }
        if (db.receiveGate case final gate? when !gate.isCompleted) {
          gate.complete();
        }
        await Future.wait(session.operations);
        await tester.pumpWidget(const SizedBox());
        await home.controller.settled;
        if (!home.controller.isDisposed) home.controller.dispose();
        await db.customSelect('SELECT 1').get();
        await db.close();
        await pumpEventQueue();
      });
      messenger.setMockMethodCallHandler(paths, null);
      messenger.setMockMethodCallHandler(permissions, null);
      messenger.setMockMethodCallHandler(notifications, null);
      dir.deleteSync(recursive: true);
    });
    return session;
  }

  testWidgets('초기화가 끝날 때까지 새 펫 만들기를 노출하지 않는다', (tester) async {
    final s = await mount(tester);
    await tester.runAsync(() async {
      s.db.resetGate = Completer<void>();
      s.startReset();
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(s.home.controller.isDisposed, isFalse);
    await tester.runAsync(() async {
      s.db.resetGate!.complete();
      await Future.wait(s.operations);
    });
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(await tester.runAsync(() => s.db.loadPet()), isNull);
    expect(s.errors, isEmpty);
  });

  testWidgets('초기화는 늦은 AI 대화와 일기를 기다린 뒤 모두 지운다', (tester) async {
    final s = await mount(tester);
    await tester.runAsync(() async {
      final brain = _HeldBrain();
      s.brain = brain;
      s.home.controller.brain = brain;
      await s.db.addEvent('feed', '합성 밥 기록', s.now);
      s.operations.add(s.home.controller.talk('오늘 발표했어').then((_) {}));
      s.operations.add(s.home.controller.writeDiary(s.now).then((_) {}));
      await Future.wait([brain.talkStarted.future, brain.diaryStarted.future]);
      s.startReset();
      await pumpEventQueue();
      expect(s.db.resets, 0);
      s.home.controller.wake();
      s.home.controller.tick(1);
      brain.gate.complete();
      await Future.wait(s.operations);
      expect(await s.db.recentMemories(10), isEmpty);
      expect(await s.db.allDiaries(), isEmpty);
      expect(await s.db.eventsOn(s.now), isEmpty);
      expect(await s.db.allCarried(), isEmpty);
    });
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(s.errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('초기화 도중 돌아온 미리보기가 이전 일기 창을 열지 않는다', (tester) async {
    final s = await mount(tester);
    await tester.runAsync(() async {
      final brain = _HeldBrain();
      s.brain = brain;
      s.home.controller.brain = brain;
      await s.db.addEvent('feed', '합성 밥 기록', s.now);
      s.db.resetGate = Completer<void>();
    });
    await tester.tap(find.text('일기'));
    await tester.pump();
    await tester.tap(find.text('오늘 미리 보기'));
    await tester.runAsync(() async {
      await s.brain!.diaryStarted.future;
      s.startReset();
      await pumpEventQueue();
      s.brain!.gate.complete();
      await pumpEventQueue();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final oldDialogCount = find.text('오늘 지금까지').evaluate().length;
    await tester.runAsync(() async {
      s.db.resetGate!.complete();
      await Future.wait(s.operations);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(oldDialogCount, 0);
    expect(find.text('오늘 지금까지'), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    // Let the diary query finish unsubscribing after the reset removed its view.
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('초기화 도중 끝난 물건 받기가 이전 발견 카드를 열지 않는다', (tester) async {
    final s = await mount(tester);
    await tester.runAsync(() async {
      await s.db.addCarried(items.first.id, FindSource.pocket, s.now);
      s.home.controller.carried = await s.db.allCarried();
      s.home.controller.notifyListeners();
      s.db.receiveGate = Completer<void>();
      s.db.resetGate = Completer<void>();
    });
    await tester.pump();
    await tester.tap(find.text('손 내밀기'));
    await tester.runAsync(() async {
      s.startReset();
      await pumpEventQueue();
      s.db.receiveGate!.complete();
      await pumpEventQueue();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final oldDialogCount = find.text('처음 보는 거다!').evaluate().length;
    await tester.runAsync(() async {
      s.db.resetGate!.complete();
      await Future.wait(s.operations);
      await pumpEventQueue();
    });
    await tester.pump();
    expect(oldDialogCount, 0);
    expect(find.text('처음 보는 거다!'), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DB 초기화 실패는 기존 펫과 기록을 유지하고 재시도한다', (tester) async {
    final s = await mount(tester);
    await tester.runAsync(() async {
      await s.db.addMemory('합성 이전 기억', s.now);
      await s.db.customStatement(
        "CREATE TRIGGER reject_reset BEFORE DELETE ON pets BEGIN SELECT RAISE(ABORT, 'synthetic reset failure'); END",
      );
      s.startReset();
      await Future.wait(s.operations);
      expect((await s.db.loadPet())!.id, s.home.controller.pet.id);
      expect(await s.db.recentMemories(10), hasLength(1));
    });
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(s.home.controller.isDisposed, isFalse);
    expect(s.errors, isEmpty);
    expect(find.textContaining('지우지 못했어요'), findsOneWidget);
    await tester.runAsync(() async {
      await s.db.customStatement('DROP TRIGGER reject_reset');
      s.startReset();
      await Future.wait(s.operations);
      expect(await s.db.loadPet(), isNull);
      expect(await s.db.recentMemories(10), isEmpty);
    });
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('알림 취소 실패가 완료된 초기화를 되돌리거나 오류를 던지지 않는다', (tester) async {
    final s = await mount(tester);
    notificationFails = true;
    await tester.runAsync(() async {
      s.startReset();
      await Future.wait(s.operations);
      expect(await s.db.loadPet(), isNull);
    });
    await tester.pump();
    expect(s.errors, isEmpty);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
