import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/pet_game.dart';
import 'package:mypet/main.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/services/sfx.dart';
import 'package:mypet/services/notifications.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/services/telemetry.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/c3/memo_input.dart';
import 'package:mypet/ui/c3/sticker_button.dart';
import 'package:mypet/ui/friends.dart';
import 'package:mypet/ui/home_screen.dart';
import 'package:mypet/ui/item_icon.dart';
import 'package:mypet/ui/shape_picker.dart';
import 'package:mypet/ui/play_tray.dart';
import 'package:mypet/ui/walk_card.dart';

class _RoomPlayer extends Fake implements AudioPlayer {
  int starts = 0;
  bool audible = false;
  @override
  Future<void> stop() async {
    audible = false;
  }

  @override
  Future<void> resume() async {
    starts++;
    audible = true;
  }
}

class _DelayedStepsStorage extends FlutterSecureStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  var writes = 0;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

class _Home {
  _Home(this.db, this.c, this.now);

  final AppDatabase db;
  final PetController c;
  DateTime now;
  late PetGame game;
}

class _DelayedLessonDb extends AppDatabase {
  _DelayedLessonDb() : super(NativeDatabase.memory());

  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();
  final copyFinished = Completer<void>();

  @override
  Future<void> saveTrick(Trick t, TrickProgress p) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await releaseSave.future;
    await super.saveTrick(t, p);
  }

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    await super.customStatement(statement, args);
    if (statement.startsWith('VACUUM INTO') && !copyFinished.isCompleted) {
      copyFinished.complete();
    }
  }
}

void main() {
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'steps_asked': 'true'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (_) async => 0);
    GuestFace.resetCache();
    ShapePicker.resetCache();
    ItemIcon.resetCache();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  Future<_Home> make(
    WidgetTester tester, {
    int paws = 10,
    Duration age = const Duration(days: 5),
    String? pouch,
    String? quirk,
    String? portraitPath,
    Future<int?> Function()? readStepTotal,
  }) async {
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final home = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime(2026, 10, 14, 14);
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 0xFFB5582E,
        furSecond: 0xFFF5EDE2,
        marking: 0xFF8A3A1A,
        portraitPath: portraitPath,
        now: now.subtract(age),
      );
      pet = pet.copyWith(
        lastSeenAt: now,
        paws: paws,
        pawMarks: const Value('hidden'),
        treatPouch: Value(pouch),
        quirk: Value(quirk),
      );
      await db.savePet(pet);
      late _Home result;
      final c = PetController(
        db,
        pet,
        random: Random(3),
        clock: () => result.now,
        readStepTotal: readStepTotal,
      );
      result = _Home(db, c, now);
      c.wake();
      await c.settled;
      c.stats = c.stats.copyWith(energy: 90);
      return result;
    }))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await home.c.settled;
        await pumpEventQueue(times: 30);
        home.c.dispose();
        await home.db.close();
      });
    });
    return home;
  }

  Future<void> mount(
    WidgetTester tester,
    _Home home, {
    SpeechToText? speech,
    Sfx? effects,
    FlutterSecureStorage? stepsStorage,
    TransitionBuilder? builder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        builder: builder,
        home: HomeScreen(
          controller: home.c,
          db: home.db,
          onReset: () async {},
          speech: speech,
          effects: effects,
          stepsStorage: stepsStorage,
        ),
      ),
    );
    home.game = tester
        .widget<GameWidget<PetGame>>(find.byType(GameWidget<PetGame>))
        .game!;
    home.game.pauseEngine();
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  }

  void runUntil(PetController c, bool Function() done) {
    for (var i = 0; i < 180 && !done(); i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
    expect(done(), isTrue);
  }

  testWidgets('320px 방에서도 간식을 포함한 네 돌봄 스티커가 모두 눌린다', (tester) async {
    final home = await make(tester, pouch: 'cheese_ball,jerky');
    tester.view.physicalSize = const Size(960, 2100);
    await mount(tester, home);
    for (final label in ['밥 주기', '놀아주기', '산책 가기', '간식 2']) {
      final action = find.text(label).hitTestable();
      expect(action, findsOneWidget, reason: label);
      expect(
        tester.getSize(find.bySemanticsLabel(label)).width,
        greaterThanOrEqualTo(48),
      );
    }
    await tester.tap(find.text('간식 2').hitTestable());
    await tester.pump();
    expect(home.c.pouch, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 창에서도 밥을 주고 공놀이로 들어갔다가 다시 돌볼 수 있다', (tester) async {
    final home = await make(tester);
    tester.view.physicalSize = const Size(960, 1260);
    await mount(tester, home);
    final before = home.c.stats.hunger;
    await tester.tap(find.text('밥 주기').hitTestable());
    await tester.pump();
    expect(home.c.stats.hunger, lessThan(before));
    await tester.tap(find.text('놀아주기').hitTestable());
    await tester.pump();
    expect(home.c.ball, isNot(Ball.none));
    final tray = find.byType(PlayTray);
    expect(tray, findsOneWidget);
    final close = find.descendant(of: tray, matching: find.text('그만 놀기'));
    await Scrollable.ensureVisible(tester.element(close), alignment: .5);
    await tester.pump();
    await tester.tap(close.hitTestable());
    await tester.pump();
    expect(find.text('밥 주기').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final hold in [true, false]) {
    testWidgets(
      '집에서 그만 놀기를 누르는 동안 공이 준비된다 · ${hold ? '손가락을 댄 채' : '직전 위치를 탭'}',
      (tester) async {
        final home = await make(tester);
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.625;
        tester.platformDispatcher.textScaleFactorTestValue = 1.1;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await mount(
          tester,
          home,
          builder: (context, child) => C3SystemTextScale(
            scaler: MediaQuery.textScalerOf(context),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1,
              child: child!,
            ),
          ),
        );
        await tester.tap(find.text('놀아주기').hitTestable());
        await tester.pump();
        expect(home.c.ball, Ball.carried);

        final close = find.text('그만 놀기').hitTestable();
        final downAt = tester.getCenter(close);
        final finger = hold ? await tester.startGesture(downAt) : null;
        runUntil(home.c, () => home.c.ball == Ball.ready);
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('공 던지기'), findsOneWidget);
        final upAt = tester.getCenter(close);
        if (finger != null) {
          await finger.up();
        } else {
          await tester.tapAt(downAt);
        }
        await tester.pump();

        expect(home.c.ball, Ball.none);
        expect(find.byType(PlayTray), findsNothing);
        expect(find.text('밥 주기').hitTestable(), findsOneWidget);
        expect(upAt, downAt, reason: '공 던지기와 간식 버튼이 생겨도 종료 버튼은 같은 자리에 남는다.');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('S22에서 공을 주워 오는 동안 같은 자리의 물어와가 점프로 바뀌지 않는다', (tester) async {
    final home = await make(tester, pouch: 'cheese_ball,jerky');
    final chips = Trick.values.where((t) => t.chip);
    for (final t in chips) {
      home.c.tricks[t] = TrickProgress(
        attempts: t == Trick.fetch ? 1 : 4,
        successes: t == Trick.fetch ? 0 : 3,
        days: 1,
        lastDay: dayKey(petDate(home.now)),
      );
    }
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(
      tester,
      home,
      builder: (context, child) => C3SystemTextScale(
        scaler: MediaQuery.textScalerOf(context),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1,
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('놀아주기'));
    await tester.pump();
    await tester.tap(find.text('앉아').hitTestable());
    await tester.pump();
    await tester.tap(find.text('점프').hitTestable());
    await tester.pump();
    runUntil(home.c, () => home.c.ball == Ball.ready);
    await tester.pump();

    Map<String, Offset> targets() => {
      for (final t in chips)
        t.label: tester.getCenter(
          find.bySemanticsLabel(RegExp('^${t.label},')).hitTestable(),
        ),
      '그만 놀기': tester.getCenter(find.bySemanticsLabel('그만 놀기').hitTestable()),
    };
    final original = targets();
    final fetchAt = original[Trick.fetch.label]!;
    final jumpBefore = home.c.tricks[Trick.jump]!.attempts;
    var fetchCount = home.c.tricks[Trick.fetch]!.attempts;
    final observed = <Map<String, Offset>>[];
    for (var round = 0; round < 2; round++) {
      expect(home.c.throwBall(), isTrue);
      await tester.pump();
      observed.add(targets());
      home.c.ballLanded();
      home.c.arrived();
      expect(home.c.ball, Ball.carried);
      await tester.pump();
      observed.add(targets());
      for (var tap = 0; tap < 3; tap++) {
        await tester.tapAt(fetchAt);
        await tester.pump();
        expect(
          home.c.tricks[Trick.fetch]!.attempts,
          ++fetchCount,
          reason: '공을 던지기 전 물어와 좌표로 계속 입력했다.',
        );
        expect(home.c.tricks[Trick.jump]!.attempts, jumpBefore);
        observed.add(targets());
      }
      runUntil(home.c, () => home.c.ball == Ball.ready);
      await tester.pump();
      observed.add(targets());
    }
    expect(find.bySemanticsLabel('물어와, 별 1개'), findsOneWidget);
    for (final positions in observed) {
      expect(positions, original, reason: '공 상태와 배운 표시가 바뀌어도 누를 위치는 같다.');
    }
    await tester.tapAt(original['그만 놀기']!);
    await tester.pump();
    expect(find.byType(PlayTray), findsNothing);
    expect(find.text('밥 주기').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S22 놀이 순서의 각 물어와 입력에 판정·별·화면을 연결하고 종료한다', (tester) async {
    final home = await make(tester);
    final logs = <String>[];
    await Telemetry.capturePlayTrace(logs.add, () async {
      await mount(tester, home);
      await tester.tap(find.text('놀아주기'));
      await tester.pump();
      for (final label in ['앉아', '점프', ...List.filled(9, '물어와')]) {
        await tester.tap(find.text(label).hitTestable());
        await tester.pump();
      }
      expect(home.c.tricks[Trick.fetch]!.stars, 1);
      expect(find.bySemanticsLabel('물어와, 별 1개'), findsOneWidget);
      await tester.tap(find.text('그만 놀기'));
      await tester.pump();
      expect(find.text('밥 주기').hitTestable(), findsOneWidget);
    });
    final fetch = logs.where((s) => s.contains('trick=fetch')).toList();
    final taps = fetch.where((s) => s.contains('phase=tap')).toList();
    expect(taps, hasLength(9));
    for (final tap in taps) {
      final input = RegExp(r'input=\d+').firstMatch(tap)![0]!;
      final linked = fetch.where((s) => s.split(' ').contains(input)).toList();
      for (final phase in ['pointer', 'tap', 'result', 'frame']) {
        expect(linked.where((s) => s.contains('phase=$phase')), hasLength(1));
      }
    }
    expect(
      fetch.any((s) => s.contains('phase=frame') && s.contains('stars=1')),
      isTrue,
    );
    expect(
      logs.any(
        (s) =>
            s.contains('action=close phase=frame') &&
            s.contains('menu_open=false'),
      ),
      isTrue,
    );
  });

  testWidgets('취소한 손가락 입력과 화면 읽기로 누른 물어와를 별개로 기록한다', (tester) async {
    final home = await make(tester);
    final logs = <String>[];
    await Telemetry.capturePlayTrace(logs.add, () async {
      await mount(tester, home);
      await tester.tap(find.text('놀아주기'));
      await tester.pump();
      final target = find.text('물어와').hitTestable();
      final finger = await tester.startGesture(tester.getCenter(target));
      await finger.cancel();
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel('물어와'));
      await tester.pump();
    });
    final fetch = logs.where((s) => s.contains('trick=fetch')).toList();
    expect(fetch.map((s) => RegExp(r'phase=(\w+)').firstMatch(s)![1]), [
      'pointer',
      'cancel',
      'tap',
      'result',
      'frame',
    ]);
    String? input(String s) => RegExp(r'input=(\d+)').firstMatch(s)?[1];
    expect(input(fetch[0]), input(fetch[1]));
    expect(input(fetch[1]), isNot(input(fetch[2])));
    expect(input(fetch[2]), input(fetch[4]));
  });

  testWidgets('화면에 남은 놀이판은 내부 공이 이미 치워졌어도 닫힌다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    await tester.tap(find.text('놀아주기'));
    await tester.pump();
    home.c.ball = Ball.none; // 그리는 쪽에 알림이 도착하지 않은 상태를 재현한다.
    expect(find.byType(PlayTray), findsOneWidget);
    await tester.tap(find.text('그만 놀기'));
    await tester.pump();
    expect(find.byType(PlayTray), findsNothing);
    expect(find.text('밥 주기').hitTestable(), findsOneWidget);
  });

  Future<void> closeSpeechHome(WidgetTester tester) async {
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.pump();
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
  }

  testWidgets('밥 앞에 앉은 뒤 설정을 열면 뒤에서 다음 식사 소리가 나지 않는다', (tester) async {
    final home = await make(tester, quirk: 'sitBeforeEat');
    final player = _RoomPlayer();
    final effects = Sfx(
      loadPlayer: (name) async => name == 'crunch' ? player : null,
    );
    await tester.runAsync(effects.init);
    await mount(tester, home, effects: effects);
    await tester.runAsync(() => tester.tap(find.text('밥 주기').hitTestable()));
    await tester.pump();
    expect(home.c.step.behavior, Behavior.sit);
    await tester.runAsync(() async {
      tester.semantics.tap(find.semantics.byLabel('설정'));
      await pumpEventQueue();
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      home.c.tick(1);
      home.c.tick(.3);
      await pumpEventQueue();
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.runAsync(() => pumpEventQueue());
    }
    expect(home.c.step.behavior, Behavior.eat);
    expect(player.starts, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  for (final next in ['일기', '설정', '마이크']) {
    testWidgets('쓰다듬기 직후 $next 전환은 이전 방의 소리를 멈춘다', (tester) async {
      final home = await make(tester);
      final player = _RoomPlayer();
      final effects = Sfx(loadPlayer: (_) async => player);
      await tester.runAsync(effects.init);
      final mic = next == '마이크';
      final speech = SpeechToText.withMethodChannel();
      const audio = MethodChannel('mypet/audio');
      final messenger = tester.binding.defaultBinaryMessenger;
      await mount(tester, home, effects: effects, speech: speech);
      final gate = Completer<void>();
      var queries = 0;
      messenger.setMockMethodCallHandler(audio, (_) async {
        queries++;
        if (!mic) await gate.future;
        return 2;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
      final label = home.c.bubble == null ? '콩이 쓰다듬기' : '콩이의 속마음';
      await tester.runAsync(() async {
        tester.semantics.tap(find.semantics.byLabel(label));
        await pumpEventQueue();
      });
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => pumpEventQueue(times: 4));
        await tester.pump();
      }
      expect(queries, greaterThan(0));
      if (mic) {
        expect(
          player.audible,
          isTrue,
          reason: 'ringer=$queries starts=${player.starts}',
        );
        const speechChannel = MethodChannel(
          'plugin.csdcorp.com/speech_to_text',
        );
        messenger.setMockMethodCallHandler(speechChannel, (_) async => true);
        addTearDown(
          () => messenger.setMockMethodCallHandler(speechChannel, null),
        );
        final begin =
            tester.widget<MemoInput>(find.byType(MemoInput)).onMic
                as Future<void> Function();
        await tester.runAsync(begin);
      } else {
        expect(player.starts, 0);
        await tester.runAsync(() async {
          tester.semantics.tap(find.semantics.byLabel(next));
          await pumpEventQueue();
        });
        await tester.pump();
        gate.complete();
      }
      await tester.pump();
      expect(player.audible, isFalse);
      if (!mic) expect(player.starts, 0);
      await closeSpeechHome(tester);
      await tester.pump(Duration.zero);
    });
  }

  for (final size in [const Size(392, 820), const Size(320, 420)]) {
    testWidgets('오른쪽 바닥의 강아지와 창틀 버튼을 각각 누른다 ${size.width}', (tester) async {
      final home = await make(tester);
      await tester.runAsync(() async {
        await home.db.addCarried(items.first.id, FindSource.window, home.now);
        home.c.carried = await home.db.allCarried();
        home.c.petX = .90;
        home.c.snapGen++;
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await mount(tester, home);
      home.game.update(0);
      await tester.pump();
      final room = find.byType(GameWidget<PetGame>);
      final button = find.ancestor(
        of: find.text('창틀 보기'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      final area = tester.getRect(room), control = tester.getRect(button);
      expect(area.height, greaterThan(48));
      expect(control.top, greaterThanOrEqualTo(area.bottom));
      final before = home.c.careScore;
      final body =
          area.topLeft +
          Offset(
            home.game.floorX(home.c.petX),
            home.game.petBaseline - 12 * home.game.pixelScale,
          );
      await tester.runAsync(() => tester.tapAt(body));
      await tester.pump();
      expect(home.c.careScore, greaterThan(before));
      expect(home.c.carried, hasLength(1));
      await Scrollable.ensureVisible(tester.element(button));
      await tester.pump();
      await tester.runAsync(() => tester.tap(button.hitTestable()));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => pumpEventQueue());
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(home.c.carried, isEmpty);
      expect(await tester.runAsync(home.db.allCarried), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  }

  testWidgets('Tab으로 강아지에게 가서 Enter와 Space로 쓰다듬는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    for (
      var i = 0;
      i < 24 && FocusManager.instance.primaryFocus?.debugLabel != '강아지 쓰다듬기';
      i++
    ) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, '강아지 쓰다듬기');
    for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      final care = home.c.careScore;
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(home.c.careScore, greaterThan(care));
      home.now = home.now.add(const Duration(seconds: 5));
    }
  });

  testWidgets('화면 읽기의 실행 동작으로 쓰다듬고 밥을 주고 도감 탭을 연다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    final before = home.c.careScore;
    final label = home.c.bubble == null ? '콩이 쓰다듬기' : '콩이의 속마음';
    tester.semantics.tap(find.semantics.byLabel(label));
    await tester.pump();
    expect(home.c.careScore, greaterThan(before));
    final hunger = home.c.stats.hunger;
    tester.semantics.tap(find.semantics.byLabel('밥 주기'));
    await tester.pump();
    expect(home.c.stats.hunger, lessThan(hunger));
    tester.semantics.tap(find.semantics.byLabel('도감'));
    await tester.pump();
    expect(home.c.roomHidden, isTrue);
    expect(find.text('기억 수첩').hitTestable(), findsOneWidget);
  });

  for (final photo in [null, 'build/portfolio/absent-synthetic-portrait.jpg']) {
    testWidgets('홈 사진이 없거나 사라져도 이 펫의 실제 털·모양·성장 단계를 그린다 ($photo)', (
      tester,
    ) async {
      final home = await make(tester, portraitPath: photo);
      await mount(tester, home);
      final preview = tester.widget<PetSpritePreview>(
        find.byType(PetSpritePreview),
      );
      final pet = home.c.pet;
      expect(preview.shape, pet.shape);
      expect(preview.stage, pet.stage);
      expect(preview.colors.main, pet.furMain);
      expect(preview.colors.second, pet.furSecond);
      expect(preview.colors.marking, pet.marking);
      expect(home.c.buyCosmetic('collar_sky'), isTrue);
      await tester.pump();
      final wearing = tester.widget<PetSpritePreview>(
        find.byType(PetSpritePreview),
      );
      expect(wearing.accent, home.c.pet.accent);
      expect(wearing.accent, isNot(preview.accent));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('짧은 창에서 키보드가 올라오고 내려가도 쓰던 대화와 입력 초점을 유지한다', (tester) async {
    final home = await make(tester);
    tester.view.physicalSize = const Size(960, 1260);
    await mount(tester, home);
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.tap(field.hitTestable());
    await tester.enterText(field, '보리야');
    final focus = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    expect(focus.hasFocus, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 540);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode,
      same(focus),
    );
    expect(focus.hasFocus, isTrue);
    await tester.enterText(field, '보리야 잘 잤어?');
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump(const Duration(milliseconds: 300));
    expect(focus.hasFocus, isTrue);
    expect(tester.widget<TextField>(field).controller!.text, '보리야 잘 잤어?');
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 방에서는 강아지 아래 속마음을 눌러 전문을 읽고 집으로 돌아온다', (tester) async {
    final home = await make(tester);
    tester.view.physicalSize = const Size(960, 1260);
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 60);
    await mount(tester, home);
    expect(home.c.startWalk(), isTrue);
    await tester.pump();
    final game = find.byType(GameWidget<PetGame>);
    final thought = find.widgetWithText(TextButton, '산책이다!');
    expect(home.game.showThoughtInRoom, isFalse);
    final announced = tester
        .getSemantics(find.bySemanticsLabel('콩이의 속마음'))
        .getSemanticsData();
    expect(announced.flagsCollection.isLiveRegion, isTrue);
    expect(announced.value, '산책이다!');
    expect(
      tester.getBottomLeft(game).dy,
      lessThanOrEqualTo(tester.getTopLeft(thought).dy),
    );
    expect(tester.getSize(game).height, greaterThan(70));
    await tester.tap(thought.hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('콩이의 속마음'), findsOneWidget);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(home.c.walking, isTrue);
    expect(home.c.uiBusy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 창에서 카페의 개인기를 펼쳐도 방과 돌아오는 버튼이 남는다', (tester) async {
    final home = await make(tester);
    tester.view.physicalSize = const Size(960, 1260);
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 60);
    await mount(tester, home);
    await tester.tap(find.text('동네 지도').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('카페').hitTestable());
    await tester.pump(const Duration(milliseconds: 350));
    expect(home.c.atCafe, isTrue);
    await tester.tap(find.text('개인기').hitTestable());
    await tester.pump();
    expect(
      tester.getSize(find.byType(GameWidget<PetGame>)).height,
      greaterThan(70),
    );
    final close = find.text('그만 놀기');
    await Scrollable.ensureVisible(tester.element(close), alignment: .5);
    await tester.pump();
    await tester.tap(close.hitTestable());
    await tester.pump();
    await tester.ensureVisible(find.text('집으로'));
    await tester.tap(find.text('집으로').hitTestable());
    await tester.pump();
    expect(home.c.out, isFalse);
    // 카페를 떠난 직후의 친구 카드 확인 주기가 종료되는 것까지 검증한다.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('화면 읽기로 준비된 공을 던지면 방에서 튀고 강아지가 쫓는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    tester.semantics.tap(find.semantics.byLabel('놀아주기'));
    await tester.pump();
    expect(find.text('공 던지기'), findsNothing);
    runUntil(home.c, () => home.c.ball == Ball.ready);
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel('공 던지기'));
    await tester.pump();
    expect(home.c.ball, Ball.thrown);
    expect(home.c.step.tag, StepTag.chase);
    expect(find.text('공 던지기'), findsNothing);
    for (var i = 0; i < 600 && home.c.ball == Ball.thrown; i++) {
      home.game.update(1 / 60);
    }
    expect(home.c.ball, isNot(Ball.thrown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('집 사진의 동네 지도에서 가게로 가고 돌아오면 다시 지도를 열 수 있다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    final map = find.text('동네 지도').hitTestable();
    await tester.tap(map);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('어디 갈까?'), findsOneWidget);
    await tester.tap(find.text('간식 가게').hitTestable());
    await tester.pump(const Duration(milliseconds: 350));
    expect(home.c.spot, Spot.treatShop);
    expect(map, findsNothing);
    await tester.tap(find.text('집으로').hitTestable());
    await tester.pump();
    expect(home.c.spot, Spot.home);
    expect(map, findsOneWidget);
  });

  testWidgets('그림 안의 속마음을 화면 읽기에서도 같은 문장으로 읽는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    expect(home.c.startWalk(), isTrue);
    await tester.pump();
    final node = tester.getSemantics(find.bySemanticsLabel('콩이의 속마음'));
    expect(node.value, '산책이다!');
    expect(home.c.bubble, node.value);
  });

  testWidgets('일기·도감에서 시스템 뒤로를 누르면 돌보던 집으로 돌아간다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    for (final tab in ['일기', '도감']) {
      await tester.tap(find.text(tab).hitTestable());
      await tester.pump();
      expect(home.c.roomHidden, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(home.c.roomHidden, isFalse);
      expect(find.text('밥 주기').hitTestable(), findsOneWidget);
    }
  });

  testWidgets('가게 버튼으로 사고 하나 더 사면 발도장·주머니·집 버튼이 함께 바뀐다', (tester) async {
    final home = await make(tester);
    expect(home.c.goToTreatShop(), isTrue);
    runUntil(home.c, () => home.c.pickShown);
    await mount(tester, home);
    await tester.tap(find.text('사 주기'));
    await tester.pump();
    expect(find.text('사 주기'), findsNothing);
    expect(find.text('발도장 3'), findsOneWidget);
    await tester.tap(find.text('발도장 3'));
    await tester.pump();
    await tester.tap(find.text('발도장 3'));
    await tester.pump();
    expect(home.c.pouch, hasLength(3));
    expect(home.c.pet.paws, 4);
    expect(find.text('발도장 3'), findsNothing);
    await tester.tap(find.text('집으로'));
    await tester.pump();
    expect(find.text('간식 3'), findsOneWidget);
    await tester.runAsync(() async {
      await home.c.settled;
      expect((await home.db.loadPet())!.paws, 4);
      expect((await home.db.loadPet())!.treatPouch, home.c.pet.treatPouch);
    });
  });

  testWidgets('친구 카드에서 나눠 주면 닫히고 같은 날 다시 열어도 나눠 주기가 없다', (tester) async {
    final home = await make(tester, pouch: 'cheese_ball,jerky');
    expect(home.c.goToCafe(), isTrue);
    await tester.runAsync(() => home.c.settled);
    final guest = home.c.guests.first;
    home.c.friends[guest.id] = const Friendship(bond: Bond.sniff, days: 2);
    await mount(tester, home);
    home.game.onGuestTap!(guest);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('치즈 볼을 나눠 주기'), findsOneWidget);
    await tester.tap(find.text('치즈 볼을 나눠 주기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsNothing);
    expect(home.c.uiBusy, isFalse);
    expect(home.c.pouch, ['jerky']);
    expect(home.c.friends[guest.id]!.bond, Bond.sniff);
    home.game.onGuestTap!(guest);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('나눠 주기'), findsNothing);
    await tester.runAsync(() async {
      final shares = (await home.db.eventsOn(
        home.now,
      )).where((e) => e.kind == 'share');
      expect(shares, hasLength(1));
    });
  });

  testWidgets('산책 중 일기에서 뒤로 누르면 먼저 집에 오고, 취소한 산책은 계속 걷는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    expect(home.c.startWalk(), isTrue);
    home.c.updateWalkSteps(213);
    await tester.pump();
    await tester.tap(find.text('일기').hitTestable());
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('산책을 마칠까요?'), findsNothing);
    expect(home.c.roomHidden, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('산책을 마칠까요?'), findsOneWidget);
    await tester.tap(find.text('계속 걷기'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(home.c.walking, isTrue);
    expect(home.c.walkSteps, 213);
    expect(home.c.uiBusy, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 350));
    expect(home.c.walking, isTrue);
    expect(await tester.runAsync(() => home.db.eventsOfKind('walk')), isEmpty);
  });

  testWidgets('뒤로 마친 산책의 지도는 일기에서 같은 그림과 걸음으로 다시 열고 보상은 한 번 받는다', (
    tester,
  ) async {
    final home = await make(tester);
    await mount(tester, home);
    expect(home.c.startWalk(), isTrue);
    runUntil(home.c, () => home.c.walkSniffs >= 2);
    home.now = home.now.add(const Duration(minutes: 15));
    home.c.updateWalkSteps(2140);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('산책 마치기'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    final original = tester.widget<WalkMap>(find.byType(WalkMap));
    expect(original.summary, contains('2,140걸음'));
    expect(home.c.uiBusy, isTrue);
    final paws = home.c.paws;
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() => home.c.settled);
    await tester.tap(find.text('일기').hitTestable());
    await tester.pump();
    await tester.tap(find.text('산책 기록').hitTestable());
    await tester.pump(const Duration(milliseconds: 350));
    for (var i = 0; i < 8 && find.text('산책 지도 보기').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.tap(find.text('산책 지도 보기').hitTestable());
    await tester.pump(const Duration(milliseconds: 350));
    final opened = tester.widget<WalkMap>(find.byType(WalkMap));
    expect(opened.startedAt, original.startedAt);
    expect(opened.spots, original.spots);
    expect(opened.summary, original.summary);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('콩이의 일기').hitTestable(), findsOneWidget);
    expect(home.c.paws, paws);
    expect(
      await tester.runAsync(() => home.db.eventsOfKind('walk')),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('산책 기록 저장에 실패하면 집에서 다시 저장하고 같은 걸음을 한 번만 남긴다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    await tester.runAsync(
      () => home.db.customStatement(
        "CREATE TRIGGER reject_walk BEFORE INSERT ON events WHEN NEW.kind='walk' BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      ),
    );
    expect(home.c.startWalk(), isTrue);
    home.c.updateWalkSteps(18);
    await tester.pump();
    await tester.tap(find.text('집으로').hitTestable());
    await tester.runAsync(() => home.c.lastWalkRecord!.saved);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('산책 기록 1건을 저장하지 못했어요.'), findsOneWidget);
    await tester.runAsync(
      () => home.db.customStatement('DROP TRIGGER reject_walk'),
    );
    await tester.tap(find.text('다시 저장').hitTestable());
    await tester.runAsync(() => home.c.settled);
    await tester.pump();
    final visits = await tester.runAsync(() => home.db.eventsOfKind('walk'));
    expect(visits!.single.detail, contains('18걸음'));
    expect(tester.takeException(), isNull);
  });

  for (final target in ['diary', 'home']) {
    testWidgets('산책 수첩의 지도를 연 상태에서 알림을 누르면 지정한 탭으로 간다 ($target)', (
      tester,
    ) async {
      final home = await make(tester);
      await mount(tester, home);
      expect(home.c.startWalk(), isTrue);
      home.now = home.now.add(const Duration(minutes: 4));
      home.c.endWalk();
      await tester.runAsync(() => home.c.settled);
      await tester.tap(find.text('일기').hitTestable());
      await tester.pump();
      await tester.tap(find.text('산책 기록').hitTestable());
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0; i < 8 && find.text('산책 지도 보기').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final journalButton = find.text('산책 지도 보기').hitTestable();
      final journalRoute = ModalRoute.of(tester.element(journalButton))!;
      expect(journalRoute.settings.name, 'walk-journal');
      await tester.tap(journalButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final mapRoute = ModalRoute.of(tester.element(find.byType(WalkMap)))!;
      expect(mapRoute.settings.name, 'walk-map');
      Notifications.opened.value = target;
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => pumpEventQueue(times: 2));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(mapRoute.isActive, isFalse);
      expect(journalRoute.isActive, isFalse);
      expect(find.byType(WalkMap).hitTestable(), findsNothing);
      expect(find.text('산책 지도 보기').hitTestable(), findsNothing);
      expect(
        find.text(target == 'home' ? '밥 주기' : '오늘 미리 보기').hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('산책 집으로 버튼은 지도 한 장을 열고 닫으면 화면 가림 상태를 푼다', (tester) async {
    final home = await make(tester);
    expect(home.c.startWalk(), isTrue);
    runUntil(home.c, () => home.c.walkSniffs >= 2);
    home.now = home.now.add(const Duration(minutes: 15));
    home.c.updateWalkSteps(2140);
    await mount(tester, home);
    await tester.tap(find.text('집으로'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WalkMap), findsOneWidget);
    expect(find.text('콩이의 산책 지도'), findsOneWidget);
    expect(find.textContaining('2,140걸음'), findsOneWidget);
    expect(home.c.walking, isFalse);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(WalkMap), findsNothing);
    expect(home.c.uiBusy, isFalse);
    await tester.runAsync(() async {
      final events = await home.db.eventsOn(home.now);
      expect(events.where((e) => e.kind == 'walk'), hasLength(1));
      expect(events.where((e) => e.kind == 'walk_spot'), hasLength(1));
    });
  });

  testWidgets('센서를 기다리는 산책은 시간을 재고 단절 뒤 마지막 확인값을 지도에 남긴다', (tester) async {
    final home = await make(tester);
    expect(home.c.startWalk(), isTrue);
    await mount(tester, home);
    expect(find.text('걸음 센서 대기 중'), findsOneWidget);
    home.c.markWalkSensorUnavailable();
    await tester.pump();
    expect(find.text('시간으로 기록 중'), findsOneWidget);
    home.c.updateWalkSteps(120);
    await tester.pump();
    expect(find.text('확인한 120걸음'), findsOneWidget);
    home.now = home.now.add(const Duration(minutes: 2));
    await tester.tap(find.text('집으로'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<WalkMap>(find.byType(WalkMap)).summary,
      contains('확인한 120걸음'),
    );
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('나갔다 바로 집으로 누르면 지도 대신 짧은 산책 안내만 보인다', (tester) async {
    final home = await make(tester);
    expect(home.c.startWalk(), isTrue);
    await mount(tester, home);
    await tester.tap(find.text('집으로'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WalkMap), findsNothing);
    expect(find.text('잠깐 다녀왔어요 · 시간으로 기록'), findsOneWidget);
    expect(home.c.uiBusy, isFalse);
  });

  testWidgets('1분 미만 산책은 킁킁댄 자리가 있어도 지도 대신 한 줄로 끝난다', (tester) async {
    final home = await make(tester);
    expect(home.c.startWalk(), isTrue);
    runUntil(home.c, () => home.c.walkSniffs >= 2);
    home.now = home.now.add(const Duration(seconds: 59));
    await mount(tester, home);
    await tester.tap(find.text('집으로'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WalkMap), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('잠깐 다녀왔어요 · 시간으로 기록'), findsOneWidget);
    expect(home.c.uiBusy, isFalse);
  });

  testWidgets('1분 산책은 킁킁댄 자리와 함께 지도를 연다', (tester) async {
    final home = await make(tester);
    expect(home.c.startWalk(), isTrue);
    runUntil(home.c, () => home.c.walkSniffs >= 2);
    home.now = home.now.add(const Duration(minutes: 1));
    await mount(tester, home);
    await tester.tap(find.text('집으로'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WalkMap), findsOneWidget);
    expect(find.text('콩이의 산책 지도'), findsOneWidget);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('확인'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(home.c.uiBusy, isFalse);
  });

  Future<void> drainPermission(WidgetTester tester) async {
    for (var i = 0; i < 24; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  testWidgets('처음 24시간은 걸음 권한 창 없이 펫을 만지고 산책을 직접 고를 수 있다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final home = await make(tester, age: const Duration(hours: 23));
    await mount(tester, home);
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.widgetWithText(StickerButton, '산책 가기').hitTestable(),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(
        () => const FlutterSecureStorage().read(key: 'steps_asked'),
      ),
      isNull,
    );
  });

  testWidgets('첫날 열어 둔 홈에 하루 뒤 돌아와도 걸음 안내는 한 번만 뜬다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final home = await make(tester, age: const Duration(hours: 23));
    await mount(tester, home);
    expect(find.byType(Dialog), findsNothing);
    void resume() {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    home.now = home.now.add(const Duration(hours: 2));
    await tester.runAsync(() async {
      resume();
      await pumpEventQueue();
    });
    await drainPermission(tester);
    expect(find.text('좋아요'), findsOneWidget);
    await tester.runAsync(() async {
      resume();
      await pumpEventQueue();
    });
    await drainPermission(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('나중에'));
    await tester.pump(const Duration(milliseconds: 350));
    await drainPermission(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(home.c.uiBusy, isFalse);
  });

  testWidgets('권한 상태 조회 중 아침 일기를 열면 집으로 돌아온 뒤 걸음 안내를 보여 준다', (tester) async {
    final home = await make(tester);
    FlutterSecureStorage.setMockInitialValues({});
    final status = (await tester.runAsync(() async => Completer<int>()))!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (_) async => status.future);
    await mount(tester, home);
    Notifications.opened.value = 'diary';
    await tester.pump();
    expect(find.text('오늘 미리 보기').hitTestable(), findsOneWidget);

    await tester.runAsync(() async {
      status.complete(0);
      await pumpEventQueue();
    });
    await drainPermission(tester);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('집').hitTestable());
    await drainPermission(tester);
    expect(find.text('좋아요'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pump(const Duration(milliseconds: 350));
    await drainPermission(tester);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('처음 안내 저장이 느려도 보지 않은 안내를 기록해 새 홈에서 생략하지 않는다', (tester) async {
    final home = await make(tester);
    FlutterSecureStorage.setMockInitialValues({});
    final storage = (await tester.runAsync(
      () async => _DelayedStepsStorage(),
    ))!;
    await mount(tester, home, stepsStorage: storage);
    final writesBeforeAnswer = storage.writes;
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() async {
      storage.release.complete();
      await pumpEventQueue();
    });
    await drainPermission(tester);
    await mount(tester, home, stepsStorage: storage);
    final hasQuestion = find.text('좋아요').evaluate().isNotEmpty;
    final asked = await tester.runAsync(() => storage.read(key: 'steps_asked'));
    expect(writesBeforeAnswer, 0);
    expect(asked, isNull);
    expect(hasQuestion, isTrue);
  });

  testWidgets('첫 안내 응답 저장 중 홈을 닫으면 늦은 저장 뒤 권한 창을 새로 열지 않는다', (tester) async {
    final home = await make(tester);
    FlutterSecureStorage.setMockInitialValues({});
    final storage = (await tester.runAsync(
      () async => _DelayedStepsStorage(),
    ))!;
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') {
            requests++;
            return {19: 1};
          }
          return 0;
        });
    await mount(tester, home, stepsStorage: storage);
    expect(find.text('좋아요'), findsOneWidget);
    await tester.tap(find.text('좋아요'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(storage.writes, 1);
    expect(home.c.uiBusy, isFalse);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() async {
      storage.release.complete();
      await pumpEventQueue();
    });
    await drainPermission(tester);
    final asked = await tester.runAsync(() => storage.read(key: 'steps_asked'));
    expect(asked, 'true');
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('첫 걸음 권한 허용을 기다리다 홈을 닫으면 이전 펫을 다시 수집하지 않는다', (tester) async {
    var reads = 0;
    final home = await make(
      tester,
      readStepTotal: () async {
        reads++;
        return null;
      },
    );
    final baseline = reads;
    FlutterSecureStorage.setMockInitialValues({});
    final granted = (await tester.runAsync(
      () async => Completer<Map<int, int>>(),
    ))!;
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') {
            requests++;
            return granted.future;
          }
          return 0;
        });
    await mount(tester, home);
    expect(find.text('좋아요'), findsOneWidget);
    await tester.tap(find.text('좋아요'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(requests, 1);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() async {
      granted.complete({19: 1});
      await pumpEventQueue();
    });
    await drainPermission(tester);
    expect(reads, baseline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('첫 걸음 권한 상태 조회 중 홈을 닫으면 안내를 보지 않았는데 본 것으로 저장하지 않는다', (
    tester,
  ) async {
    final home = await make(tester);
    FlutterSecureStorage.setMockInitialValues({});
    final status = (await tester.runAsync(() async => Completer<int>()))!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async => status.future);
    await mount(tester, home);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() async {
      status.complete(0);
      await pumpEventQueue();
    });
    await drainPermission(tester);
    final asked = await tester.runAsync(
      () => const FlutterSecureStorage().read(key: 'steps_asked'),
    );
    expect(asked, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final allowed in [true, false]) {
    testWidgets('열린 홈의 첫 걸음 권한 응답은 허용일 때만 한 번 수집한다: $allowed', (tester) async {
      var reads = 0;
      final home = await make(
        tester,
        readStepTotal: () async {
          reads++;
          return null;
        },
      );
      final baseline = reads;
      FlutterSecureStorage.setMockInitialValues({});
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissions, (call) async {
            if (call.method == 'requestPermissions') {
              requests++;
              return {19: allowed ? 1 : 0};
            }
            return 0;
          });
      await mount(tester, home);
      await tester.tap(find.text('좋아요'));
      await tester.pump(const Duration(milliseconds: 300));
      await drainPermission(tester);
      expect(requests, 1);
      expect(reads, baseline + (allowed ? 1 : 0));
      var collectionDone = false;
      home.c.collected.then((_) => collectionDone = true);
      await drainPermission(tester);
      expect(collectionDone, isTrue);
      final asked = await tester.runAsync(
        () => const FlutterSecureStorage().read(key: 'steps_asked'),
      );
      expect(asked, 'true');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('걸음 권한 대기 중 홈을 닫아도 늦은 응답이 해제된 화면을 갱신하지 않는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    final response = (await tester.runAsync(
      () async => Completer<Map<int, int>>(),
    ))!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') return response.future;
          return 0;
        });
    final start =
        tester
                .widget<StickerButton>(
                  find.widgetWithText(StickerButton, '산책 가기'),
                )
                .onTap
            as Future<void> Function();
    late Future<void> starting;
    await tester.runAsync(() async {
      starting = start();
      await pumpEventQueue();
    });
    expect(home.c.walking, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      response.complete({19: 0});
      await expectLater(starting, completes);
    });
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('걸음 권한 대기 중 산책을 끝내면 늦은 거절 안내와 타이머를 만들지 않는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    final response = (await tester.runAsync(
      () async => Completer<Map<int, int>>(),
    ))!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') return response.future;
          return 0;
        });
    final start =
        tester
                .widget<StickerButton>(
                  find.widgetWithText(StickerButton, '산책 가기'),
                )
                .onTap
            as Future<void> Function();
    late Future<void> starting;
    await tester.runAsync(() async {
      starting = start();
      await pumpEventQueue();
    });
    await tester.pump();
    await tester.tap(find.text('집으로'));
    await tester.pump();
    expect(home.c.walking, isFalse);
    await tester.runAsync(() async {
      response.complete({19: 0});
      await starting;
    });
    // 먼저 표시된 짧은 산책 안내 뒤에 늦은 권한 안내가 대기열에 쌓이지 않아야 한다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('걸음 수 권한이 없어서 시간만 재요.'), findsNothing);
    expect(find.textContaining('산책 중 ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('같은 산책 시작 콜백을 다시 눌러도 권한 요청과 타이머를 중복하지 않는다', (tester) async {
    final home = await make(tester);
    await mount(tester, home);
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          if (call.method == 'requestPermissions') {
            requests++;
            return {19: 0};
          }
          return 0;
        });
    final start =
        tester
                .widget<StickerButton>(
                  find.widgetWithText(StickerButton, '산책 가기'),
                )
                .onTap
            as Future<void> Function();
    // 첫 시작 뒤 아직 다시 그리지 않은 버튼의 같은 콜백을 한 번 더 누른다.
    await tester.runAsync(() async {
      await start();
      await start();
    });
    await tester.pump();
    await tester.tap(find.text('집으로'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    // start를 runAsync에서 호출했으므로 그곳에서 만들어졌을 실제 타이머도 기다린다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(requests, 1);
  });

  const speechChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> speechEvent(
    WidgetTester tester,
    String method,
    Object value,
  ) async {
    await tester.runAsync(() async {
      final reply = await messenger.handlePlatformMessage(
        speechChannel.name,
        speechChannel.codec.encodeMethodCall(MethodCall(method, value)),
        null,
      );
      if (reply != null) speechChannel.codec.decodeEnvelope(reply);
      await pumpEventQueue();
    });
    await tester.pump();
  }

  String recognized(String words, {bool finalResult = false}) => jsonEncode({
    'alternates': [
      {'recognizedWords': words, 'confidence': 1.0},
    ],
    'resultType': finalResult ? 2 : 0,
  });

  testWidgets('음성 초기화를 기다리다 홈을 닫으면 늦은 허용으로 녹음을 시작하지 않는다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    final ready = (await tester.runAsync(() async => Completer<bool>()))!;
    var listens = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') return ready.future;
      if (call.method == 'listen') {
        listens++;
        return true;
      }
      return null;
    });
    await mount(tester, home, speech: speech);
    final mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    late Future<void> starting;
    await tester.runAsync(() async {
      starting = mic();
      await pumpEventQueue();
    });
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() async {
      ready.complete(true);
      await expectLater(starting, completes);
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(listens, 0);
    await closeSpeechHome(tester);
  });

  testWidgets('음성을 듣던 홈을 닫으면 녹음을 취소하고 늦은 최종 결과를 버린다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    var cancels = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize' || call.method == 'listen') return true;
      if (call.method == 'cancel') cancels++;
      return null;
    });
    await mount(tester, home, speech: speech);
    final mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await tester.pump();
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isTrue);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() => pumpEventQueue());
    await speechEvent(
      tester,
      'textRecognition',
      recognized('앉아', finalResult: true),
    );
    await closeSpeechHome(tester);
    expect(cancels, 1);
    expect(home.c.tricks[Trick.sit]?.attempts ?? 0, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('음성 초기화 중 연속 탭은 녹음을 중복하지 않고 부분 결과는 최종 때만 보낸다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    final ready = (await tester.runAsync(() async => Completer<bool>()))!;
    var initializes = 0, listens = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') {
        initializes++;
        return ready.future;
      }
      if (call.method == 'listen') {
        listens++;
        return true;
      }
      return null;
    });
    await mount(tester, home, speech: speech);
    final mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(() async {
      final first = mic(), second = mic();
      await pumpEventQueue();
      ready.complete(true);
      await Future.wait([first, second]);
    });
    await tester.pump();
    await speechEvent(tester, 'textRecognition', recognized('앉아'));
    expect(
      tester.widget<MemoInput>(find.byType(MemoInput)).controller.text,
      '앉아',
    );
    expect(home.c.tricks[Trick.sit]?.attempts ?? 0, 0);
    await speechEvent(
      tester,
      'textRecognition',
      recognized('앉아', finalResult: true),
    );
    expect(home.c.tricks[Trick.sit]?.attempts, 1);
    expect(
      tester.widget<MemoInput>(find.byType(MemoInput)).controller.text,
      isEmpty,
    );
    expect(initializes, 1);
    expect(listens, 1);
    await closeSpeechHome(tester);
  });

  testWidgets('음성 초기화를 공유한 새 홈도 오류를 받으면 듣기 표시를 끈다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize' || call.method == 'listen') return true;
      return null;
    });
    await mount(tester, home, speech: speech);
    var mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() => pumpEventQueue());
    await mount(tester, home, speech: speech);
    mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await tester.pump();
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isTrue);
    await speechEvent(
      tester,
      'notifyError',
      jsonEncode({'errorMsg': 'error_no_match', 'permanent': true}),
    );
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isFalse);
    await closeSpeechHome(tester);
  });

  testWidgets('이전 홈의 녹음 시작 응답이 늦어도 새 홈의 첫 마이크 탭은 녹음을 시작한다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    final listened = (await tester.runAsync(() async => Completer<bool>()))!;
    var listens = 0, stops = 0, cancels = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'listen') {
        return ++listens == 1 ? listened.future : true;
      }
      if (call.method == 'stop') stops++;
      if (call.method == 'cancel') cancels++;
      return null;
    });
    await mount(tester, home, speech: speech);
    var mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    late Future<void> first;
    await tester.runAsync(() async {
      first = mic();
      await pumpEventQueue();
    });
    await speechEvent(tester, 'notifyStatus', 'listening');
    expect(speech.isListening, isTrue);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await mount(tester, home, speech: speech);
    mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    late Future<void> second;
    await tester.runAsync(() async {
      second = mic();
      await pumpEventQueue();
      listened.complete(true);
      await Future.wait([first, second]);
    });
    await tester.pump();
    final listening = tester
        .widget<MemoInput>(find.byType(MemoInput))
        .listening;
    await closeSpeechHome(tester);
    expect(listens, 2);
    expect(stops, 0);
    expect(cancels, 2);
    expect(listening, isTrue);
  });

  testWidgets('이전 홈의 녹음 취소가 끝나기 전에 새 홈의 녹음을 시작하지 않는다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    final cancelled = (await tester.runAsync(() async => Completer<void>()))!;
    var listens = 0, cancels = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'listen') {
        listens++;
        return true;
      }
      if (call.method == 'cancel' && ++cancels == 1) await cancelled.future;
      return null;
    });
    await mount(tester, home, speech: speech);
    var mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
    await tester.runAsync(() => pumpEventQueue());
    expect(cancels, 1);
    await mount(tester, home, speech: speech);
    mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    late Future<void> starting;
    await tester.runAsync(() async {
      starting = mic();
      await pumpEventQueue();
    });
    expect(listens, 1);
    await tester.runAsync(() async {
      cancelled.complete();
      await starting;
    });
    await tester.pump();
    expect(listens, 2);
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isTrue);
    await closeSpeechHome(tester);
  });

  testWidgets('수동 녹음 종료 뒤 최종 결과는 한 번 전송하고 다시 시작할 수 있다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    var stops = 0, listens = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'listen') {
        listens++;
        return true;
      }
      if (call.method == 'stop') stops++;
      return null;
    });
    await mount(tester, home, speech: speech);
    final mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await speechEvent(tester, 'textRecognition', recognized('앉아'));
    await tester.runAsync(mic);
    await tester.pump();
    expect(stops, 1);
    expect(home.c.tricks[Trick.sit]?.attempts ?? 0, 0);
    await speechEvent(
      tester,
      'textRecognition',
      recognized('앉아', finalResult: true),
    );
    await speechEvent(
      tester,
      'textRecognition',
      recognized('앉아', finalResult: true),
    );
    expect(home.c.tricks[Trick.sit]?.attempts, 1);
    await tester.runAsync(mic);
    await tester.pump();
    expect(listens, 2);
    await speechEvent(tester, 'notifyStatus', 'doneNoResult');
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isFalse);
    await closeSpeechHome(tester);
  });

  testWidgets('음성 초기화 거절 뒤 다시 누르면 재시도하고 연결 예외 뒤에도 복구한다', (tester) async {
    final home = await make(tester);
    final speech = SpeechToText.withMethodChannel();
    var initializes = 0, listens = 0;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      if (call.method == 'initialize') return ++initializes > 1;
      if (call.method == 'listen') {
        if (++listens == 1) {
          throw PlatformException(code: 'recognizer_unavailable');
        }
        return true;
      }
      return null;
    });
    await mount(tester, home, speech: speech);
    final mic =
        tester.widget<MemoInput>(find.byType(MemoInput)).onMic
            as Future<void> Function();
    await tester.runAsync(mic);
    await tester.pump();
    expect(find.text('음성 인식을 켤 수 없어요. 마이크 권한을 확인해 주세요.'), findsOneWidget);
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isFalse);
    await tester.runAsync(mic);
    await tester.pump();
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isFalse);
    await tester.runAsync(mic);
    await tester.pump();
    expect(initializes, 2);
    expect(listens, 2);
    expect(tester.widget<MemoInput>(find.byType(MemoInput)).listening, isTrue);
    await closeSpeechHome(tester);
  });

  testWidgets('수동 친구 카드가 열린 동안 자동 친구 카드는 기다리고 겹치지 않는다', (tester) async {
    final home = await make(tester);
    for (final guest in cafeRegulars) {
      home.c.friends[guest.id] = const Friendship(
        bond: Bond.stranger,
        days: 1,
        lastDay: '2026-10-13',
      );
    }
    await mount(tester, home);
    home.game.onDoorTap!();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('카페'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => home.c.settled);
    final guest = home.c.guests.first;
    home.game.onGuestTap!(guest);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Dialog), findsOneWidget);
    runUntil(home.c, () => home.c.pendingCard != null);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(Dialog, skipOffstage: false), findsOneWidget);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog, skipOffstage: false), findsOneWidget);
    expect(home.c.uiBusy, isTrue);
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(home.c.uiBusy, isFalse);
  });

  testWidgets('하원 수업 저장 중 연습 모드를 켜도 사본에 개인기 기록이 남는다', (tester) async {
    final dir = Directory.systemTemp.createTempSync('mypet_switch_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, null);
    });
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = (await tester.runAsync(() async => _DelayedLessonDb()))!;
    var now = DateTime(2026, 10, 14, 14);
    final pet = (await tester.runAsync(
      () => db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now,
      ),
    ))!;
    final mode = TestMode(File('${dir.path}/test_mode.json'));
    await tester.runAsync(
      () => tester.pumpWidget(
        MypetApp(
          db: db,
          initialPet: pet,
          systemPrompt: '',
          diaryPrompt: '',
          ai: null,
          clock: () => now,
          testMode: mode,
          docs: dir.path,
        ),
      ),
    );
    final oldHome = tester.widget<HomeScreen>(find.byType(HomeScreen));
    var activeHome = oldHome;
    final old = oldHome.controller;
    tester
        .widget<GameWidget<PetGame>>(find.byType(GameWidget<PetGame>))
        .game!
        .pauseEngine();
    addTearDown(() async {
      if (!db.releaseSave.isCompleted) db.releaseSave.complete();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await activeHome.controller.settled;
        activeHome.controller.dispose();
        await activeHome.db.close();
      });
    });
    await tester.runAsync(() => old.settled);
    await tester.runAsync(() async {
      expect(old.goToKindergarten(), isTrue);
      expect(old.dropOff(lesson: Trick.sit), isTrue);
      now = now.add(const Duration(hours: 3));
      old.pickUp();
      await db.saveStarted.future.timeout(const Duration(seconds: 2));
      final switching = oldHome.onTestMode!(true);
      try {
        await db.copyFinished.future.timeout(const Duration(milliseconds: 200));
      } on TimeoutException {
        // 저장이 끝나기 전에는 복사가 시작되지 않는 것이 정상이다.
      }
      db.releaseSave.complete();
      await switching;
    });
    await tester.pump();
    final copied = tester.widget<HomeScreen>(find.byType(HomeScreen));
    activeHome = copied;
    tester
        .widget<GameWidget<PetGame>>(find.byType(GameWidget<PetGame>))
        .game!
        .pauseEngine();
    await tester.runAsync(() async {
      await copied.controller.settled;
      final tricks = await copied.db.loadTricks();
      expect(tricks[Trick.sit]?.successes, 1);
      final events = await copied.db.eventsOn(now);
      expect(
        events.where((e) => e.kind == 'trick' && e.detail.startsWith('유치원')),
        hasLength(1),
      );
    });
  });
}
