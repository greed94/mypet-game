import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/collection_screen.dart';
import 'package:mypet/ui/memory_notebook.dart';
import 'package:mypet/ui/keep_words.dart';

void main() {
  final at = DateTime(2026, 11, 24, 14);

  test('동시에 여섯 기억을 고정해도 대화용 다섯 자리만 채우고 다른 기억은 남는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 1; i <= 6; i++) {
      await db.addMemory('기억$i', at);
    }
    final all = await db.recentMemories(6);
    final writes = await Future.wait(
      all.map((m) => db.setMemoryPinned(m.id, true)),
    );
    expect(
      writes.where((r) => r == MemoryPinResult.saved),
      hasLength(conversationMemoryLimit),
    );
    expect(writes.where((r) => r == MemoryPinResult.full), hasLength(1));
    final used = await db.conversationMemories();
    expect(used, hasLength(conversationMemoryLimit));
    expect(used.every((m) => m.pinned), isTrue);
    expect(
      await db.setMemoryPinned(used.first.id, true),
      MemoryPinResult.saved,
    );
    final left = (await db.recentMemories(6)).singleWhere((m) => !m.pinned);
    await db.setMemoryPinned(used.first.id, false);
    expect(await db.setMemoryPinned(left.id, true), MemoryPinResult.saved);
    expect(await db.forgetMemory(left.id), isTrue);
    expect(await db.forgetMemory(left.id), isFalse);
    expect(await db.setMemoryPinned(left.id, true), MemoryPinResult.missing);
    expect((await db.recentMemories(6)).length, 5);
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  Future<AppDatabase> openBook(
    WidgetTester tester,
    List<String> memories,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, c) = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      for (final memory in memories) {
        await db.addMemory(memory, at);
      }
      final pet = await db.createPet(
        name: '보리',
        stage: PetStage.puppy,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: at,
      );
      return (db, PetController(db, pet, clock: () => at));
    }))!;
    addTearDown(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox());
        await pumpEventQueue();
        await c.settled;
        c.dispose();
        await db.close();
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Scaffold(body: CollectionScreen(controller: c)),
      ),
    );
    await tester.tap(find.text('기억 수첩').hitTestable());
    await drain(tester);
    expect(find.byType(MemoryNotebook), findsOneWidget);
    return db;
  }

  testWidgets('빈 수첩을 열어 둔 동안 새 기억을 받고, 선택한 항목만 고정하거나 지운다', (tester) async {
    final db = await openBook(tester, []);
    expect(find.text('아직 적힌 기억이 없어요'), findsOneWidget);
    // 열려 있는 수첩에 한 묶음이 추가되는 상황이다. 커밋 뒤 프레임을 펌프해 watch를 갱신한다.
    await tester.runAsync(
      () => db.transaction(() async {
        await db.addMemory('민트공', at);
        await db.addMemory('산책길', at);
      }),
    );
    await drain(tester);
    final older = (await tester.runAsync(() => db.recentMemories(2)))!.last;
    final card = find.byKey(ValueKey(older.id));
    Finder button(String tooltip) =>
        find.descendant(of: card, matching: find.byTooltip(tooltip));
    await tester.runAsync(() => tester.tap(button('기억 고정')));
    await drain(tester);
    expect(find.text('고정 1 / 5'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(keepWords('민트공'))).dy,
      lessThan(tester.getTopLeft(find.text(keepWords('산책길'))).dy),
    );
    await tester.tap(button('기억 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await drain(tester);
    expect(find.text(keepWords('민트공')), findsOneWidget);
    await tester.tap(button('기억 지우기'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => tester.tap(find.widgetWithText(FilledButton, '지우기')),
    );
    await drain(tester);
    expect(find.text(keepWords('민트공')), findsNothing);
    expect(find.text(keepWords('산책길')), findsOneWidget);
    expect(find.text('고정 0 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('오래된 기억은 더 보기를 눌렀을 때 읽을 수 있다', (tester) async {
    await openBook(tester, [for (var i = 1; i <= 34; i++) '기록$i']);
    final more = find.text('이전 기억 더 보기');
    final scroll = find
        .descendant(
          of: find.byType(MemoryNotebook),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(more, 350, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(more), alignment: .5);
    await tester.pump();
    await tester.tap(more.hitTestable());
    await drain(tester);
    final first = find.text(keepWords('기록1'));
    await tester.scrollUntilVisible(first, 300, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(first), alignment: .5);
    await tester.pump();
    expect(first.hitTestable(), findsOneWidget);
    expect(more, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
