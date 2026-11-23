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
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(() async {
      final db = _ReadDatabase()..failList = failList;
      final pet = await db.createPet(
        name: '검사펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now,
      );
      await db.addDiary('2026-10-27', '저장된 검사 일기', now, byAi: true);
      await db.addEvent('feed', '주인이 밥을 줬다', now);
      return (db, PetController(db, pet, clock: () => now));
    }))!;
    final (db, c) = fixture;
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
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: DiaryScreen(controller: c, db: db),
        ),
      ),
    );
    await drain(tester);
    return fixture;
  }

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
    expect(find.text('AI'), findsOneWidget);
  });
}
