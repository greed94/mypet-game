import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/diary_screen.dart';

class _ReadDatabase extends AppDatabase {
  _ReadDatabase() : super(NativeDatabase.memory());

  bool failList = false;
  bool failEvents = false;
  bool failPhoto = false;
  bool failTrail = false;
  Completer<void>? laterTrailPage;

  @override
  Stream<List<({DateTime at, String kind})>> watchDiaryActions(
    DateTime day,
    Iterable<String> kinds,
    int limit,
  ) {
    if (failTrail) return Stream.error(StateError('synthetic trail failure'));
    final rows = super.watchDiaryActions(day, kinds, limit);
    final gate = laterTrailPage;
    return gate == null || limit <= 6
        ? rows
        : Stream.fromFuture(gate.future).asyncExpand((_) => rows);
  }

  Completer<void>? listGate;
  Completer<void>? eventGate;
  int photoReads = 0;

  @override
  Future<List<Diary>> allDiaries() async {
    await listGate?.future;
    if (failList) throw StateError('synthetic read failure');
    return super.allDiaries();
  }

  @override
  Future<List<Event>> eventsOn(DateTime day) async {
    await eventGate?.future;
    if (failEvents) throw StateError('synthetic event failure');
    return super.eventsOn(day);
  }

  @override
  Future<KinderPhotoRow?> kinderPhotoOn(String day) async {
    photoReads++;
    if (failPhoto) throw StateError('synthetic photo failure');
    return super.kinderPhotoOn(day);
  }
}

void main() {
  final now = DateTime(2026, 10, 28, 12);

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<(_ReadDatabase, PetController)> mount(
    WidgetTester tester, {
    bool failList = false,
    bool savedDiary = true,
    bool wakeOnOpen = false,
    DateTime? openedAt,
    DateTime Function()? clock,
    Future<void> Function(_ReadDatabase)? prepare,
    ValueNotifier<bool>? visibility,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(() async {
      final db = _ReadDatabase()..failList = failList;
      final open = clock?.call() ?? openedAt ?? now;
      final pet = await db.createPet(
        name: '검사펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: savedDiary ? now : open.subtract(const Duration(hours: 4)),
      );
      if (savedDiary) {
        await db.addDiary('2026-10-27', '저장된 검사 일기', now, byAi: true);
        await db.addEvent('feed', '주인이 밥을 줬다', now);
      }
      await prepare?.call(db);
      final controller = PetController(db, pet, clock: clock ?? () => open);
      if (wakeOnOpen) controller.wake();
      return (db, controller);
    }))!;
    final (db, c) = fixture;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        await c.settled;
        c.dispose();
        await db.close();
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: visibility == null
              ? DiaryScreen(controller: c, db: db)
              : ValueListenableBuilder<bool>(
                  valueListenable: visibility,
                  builder: (_, visible, _) =>
                      DiaryScreen(controller: c, db: db, visible: visible),
                ),
        ),
      ),
    );
    await drain(tester);
    return fixture;
  }

  testWidgets('새벽 첫 장에는 실제 만남과 식사 시각이 들어오고 같은 날 새벽 5시를 안내한다', (tester) async {
    final opening = DateTime(2026, 11, 24, 3, 45);
    final (db, _) = await mount(tester, savedDiary: false, openedAt: opening);
    expect(find.text('함께 쓰는 첫 장'), findsOneWidget);
    expect(find.textContaining('11월 24일 새벽 5시'), findsOneWidget);
    final meeting = DateTime(2026, 11, 23, 23, 59);
    final recording = (await tester.runAsync(() async {
      final writing = db.transaction(() async {
        await db.queueFirstMeeting(meeting);
        await db.beginFirstMeeting(meeting);
        await db.addEvent('feed', '주인이 밥을 줬다', DateTime(2026, 11, 24, 0, 7));
        await db.addEvent('talk', '비공개 합성 대화', opening);
        await db.addEvent('grow', '다음 날의 성장', DateTime(2026, 11, 24, 5));
      });
      return (writing: writing);
    }))!;
    await drain(tester);
    await tester.runAsync(() => recording.writing);
    await drain(tester);
    expect(find.text('처음 만남'), findsOneWidget);
    expect(find.text('23:59'), findsOneWidget);
    expect(find.text('다음 날 00:07'), findsOneWidget);
    expect(find.text('밥 먹기'), findsOneWidget);
    expect(find.text('비공개 합성 대화'), findsNothing);
    expect(find.text('어른 강아지가 된 날'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('05시 뒤 첫 실행에서 지난 일기를 쓰는 중이면 다음 날을 기다리라는 안내를 띄우지 않는다', (
    tester,
  ) async {
    final open = DateTime(2026, 11, 24, 7);
    final gate = Completer<void>();
    final (db, c) = await mount(
      tester,
      savedDiary: false,
      openedAt: open,
      wakeOnOpen: true,
      prepare: (db) async {
        await db.addEvent('feed', '주인이 밥을 줬다', DateTime(2026, 11, 24, 4, 34));
        db.eventGate = gate;
      },
    );
    expect(c.writingDueDiaries, isTrue);
    expect(find.text('지난 하루를 일기에 담고 있어요.'), findsOneWidget);
    expect(find.textContaining('11월 25일 새벽 5시'), findsNothing);
    db.listGate = Completer<void>();
    gate.complete();
    for (var i = 0; i < 12 && c.writingDueDiaries; i++) {
      await drain(tester);
    }
    await drain(tester);
    expect(find.text('저장한 일기를 펼치고 있어요.'), findsOneWidget);
    expect(find.textContaining('11월 25일 새벽 5시'), findsNothing);
    db.listGate!.complete();
    await drain(tester);
    final dates = (await tester.runAsync(db.allDiaries))!;
    expect(dates.single.day, '2026-11-23');
    expect(find.text('지난 하루를 일기에 담고 있어요.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  });

  for (final hidden in [false, true]) {
    testWidgets('앱을 닫지 않고 05시를 지나면 지난 일기를 만들고 저장소 복구 뒤 같은 날 다시 쓴다 (숨김 $hidden)', (
      tester,
    ) async {
      var at = DateTime(2026, 11, 24, 4, 59, 55);
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      final (db, c) = await mount(
        tester,
        savedDiary: false,
        clock: () => at,
        visibility: visible,
        prepare: (db) async {
          await db.addEvent('feed', '주인이 밥을 줬다', at);
          await db.customStatement(
            "CREATE TRIGGER denied_diary BEFORE INSERT ON diaries BEGIN SELECT RAISE(ABORT, 'synthetic full'); END",
          );
        },
      );
      expect(find.textContaining('11월 24일 새벽 5시'), findsOneWidget);
      if (hidden) {
        visible.value = false;
        await tester.pump();
      }
      at = DateTime(2026, 11, 24, 5, 0, 2);
      await tester.pump(const Duration(seconds: 7));
      if (hidden) {
        visible.value = true;
        await tester.pump();
      }
      for (var i = 0; i < 12 && !c.diarySaveFailed; i++) {
        await drain(tester);
      }
      expect(c.diarySaveFailed, isTrue);
      await drain(tester);
      expect(find.text('지난 일기 다시 쓰기'), findsOneWidget);
      await tester.runAsync(
        () => db.customStatement('DROP TRIGGER denied_diary'),
      );
      await tester.tap(find.text('지난 일기 다시 쓰기'));
      for (var i = 0; i < 12 && c.diarySaveFailed; i++) {
        await drain(tester);
      }
      await drain(tester);
      expect(c.diarySaveFailed, isFalse);
      final diaries = (await tester.runAsync(db.allDiaries))!;
      expect(diaries.single.day, '2026-11-23');
      expect(diaries.single.content, contains('밥을 줬다'));
      expect(find.text('지난 일기 다시 쓰기'), findsNothing);
      expect(find.text('함께 쓰는 첫 장'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
    });
  }

  testWidgets('저장된 일기의 발자국은 실패 후 다시 읽고 같은 시각의 다섯 건 뒤를 펼친다', (tester) async {
    final (db, c) = await mount(tester, scale: 1.5);
    final at = DateTime(2026, 10, 27, 16);
    expect(find.bySemanticsLabel(RegExp('10월 27일 그날의 발자국')), findsOneWidget);
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await db.addEvent('pet', '주인이 쓰다듬어 줬다', at);
      }
      await db.addEvent('walk', '짧은 산책', at);
    });
    db.failTrail = true;
    await tester.tap(find.text('그날의 발자국'));
    await drain(tester);
    expect(find.text('발자국 다시 읽기'), findsOneWidget);
    db.failTrail = false;
    await tester.tap(find.text('발자국 다시 읽기'));
    await drain(tester);
    expect(find.text('쓰다듬기'), findsNWidgets(5));
    expect(find.text('산책에서 귀가'), findsNothing);
    await tester.ensureVisible(find.text('발자국 더 보기'));
    db.laterTrailPage = Completer<void>();
    await tester.tap(find.text('발자국 더 보기'));
    await drain(tester);
    expect(find.text('쓰다듬기'), findsNWidgets(5));
    expect(find.text('발자국 더 보기'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    db.laterTrailPage!.complete();
    await drain(tester);
    expect(find.text('산책에서 귀가'), findsOneWidget);
    final writing = (await tester.runAsync(
      () async => (done: c.writeDiary(now)),
    ))!;
    await drain(tester);
    await tester.runAsync(() => writing.done);
    await drain(tester);
    final october27 = find.bySemanticsLabel(RegExp('10월 27일 그날의 발자국'));
    final october28 = find.bySemanticsLabel(RegExp('10월 28일 그날의 발자국'));
    await tester.scrollUntilVisible(
      october27,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await drain(tester);
    expect(find.text('산책에서 귀가'), findsOneWidget);
    await tester.scrollUntilVisible(
      october28,
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(october28, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('목록 읽기 실패를 빈 일기로 숨기지 않고 다시 읽는다', (tester) async {
    final (db, _) = await mount(tester, failList: true);
    expect(find.textContaining('아직 일기가 없어요'), findsNothing);
    expect(find.text('다시 읽기'), findsOneWidget);
    db.failList = false;
    await tester.tap(find.text('다시 읽기'));
    await drain(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data?.replaceAll('\u2060', '').contains('저장된 검사 일기') == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('갱신 대기와 실패 중에도 읽던 일기를 유지한다', (tester) async {
    final (db, c) = await mount(tester);
    db.listGate = await tester.runAsync(() async => Completer<void>());
    c.diaryVersion++;
    c.notifyListeners();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data?.replaceAll('\u2060', '').contains('저장된 검사 일기') == true,
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    db.failList = true;
    db.listGate!.complete();
    await drain(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data?.replaceAll('\u2060', '').contains('저장된 검사 일기') == true,
      ),
      findsOneWidget,
    );
    expect(find.text('다시 읽기'), findsOneWidget);
    db.failList = false;
    db.listGate = null;
    await tester.tap(find.text('다시 읽기'));
    await drain(tester);
    expect(find.text('다시 읽기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final photoFailure in [false, true]) {
    testWidgets('미리보기 ${photoFailure ? '사진' : '사건'} 읽기 실패 후 다시 시도한다', (
      tester,
    ) async {
      final (db, _) = await mount(tester);
      db.failEvents = !photoFailure;
      db.failPhoto = photoFailure;
      await tester.tap(find.text('오늘 미리 보기'));
      await drain(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('다시 시도'), findsOneWidget);
      expect(find.text('쓰는 중…'), findsNothing);
      db.failEvents = db.failPhoto = false;
      await tester.tap(find.text('오늘 미리 보기'));
      await drain(tester);
      expect(find.text('오늘 지금까지'), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
    });
  }

  for (final fails in [false, true]) {
    testWidgets('산책 기록을 읽을 때 늦은 일기 미리보기가 위로 나오지 않는다 ($fails)', (tester) async {
      final (db, _) = await mount(tester);
      db.eventGate = await tester.runAsync(() async => Completer<void>());
      await tester.tap(find.text('오늘 미리 보기'));
      await tester.pump();
      await tester.tap(find.text('산책 기록').hitTestable());
      await tester.pump(const Duration(milliseconds: 350));
      db.failEvents = fails;
      db.eventGate!.complete();
      await drain(tester);
      expect(find.text('오늘 지금까지'), findsNothing);
      expect(find.textContaining('오늘 일기를 불러오지 못했어요'), findsNothing);
      expect(db.photoReads, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('미리보기 대기 중 닫으면 사진 읽기나 새 창을 열지 않는다', (tester) async {
    final (db, _) = await mount(tester);
    db.eventGate = await tester.runAsync(() async => Completer<void>());
    await tester.tap(find.text('오늘 미리 보기'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    db.eventGate!.complete();
    await drain(tester);
    expect(db.photoReads, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('펫 교체 후 새 목록을 기다릴 때 이전 펫 일기를 보여 주지 않는다', (tester) async {
    await mount(tester);
    final oldState = tester.state(find.byType(DiaryScreen));
    final replacement = (await tester.runAsync(() async {
      final db = _ReadDatabase()..listGate = Completer<void>();
      final pet = await db.createPet(
        name: '새 검사펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now,
      );
      await db.addDiary('2026-10-27', '새 펫 검사 일기', now, byAi: false);
      return (db, PetController(db, pet, clock: () => now));
    }))!;
    final (db, c) = replacement;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await c.settled;
        c.dispose();
        await db.close();
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1)),
          child: child!,
        ),
        home: Scaffold(
          body: DiaryScreen(controller: c, db: db),
        ),
      ),
    );
    expect(tester.state(find.byType(DiaryScreen)), same(oldState));
    final showsOld = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data?.replaceAll('\u2060', '').contains('저장된 검사 일기') == true,
    );
    final oldCount = showsOld.evaluate().length;
    db.listGate!.complete();
    await drain(tester);
    expect(oldCount, 0);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data?.replaceAll('\u2060', '').contains('새 펫 검사 일기') == true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('큰 글씨에서도 일기 날짜와 AI 표시가 넘치지 않는다', (tester) async {
    await mount(tester, scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('AI가 쓴 일기'), findsOneWidget);
  });
}
