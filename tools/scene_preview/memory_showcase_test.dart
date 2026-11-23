// flutter test tools/scene_preview/memory_showcase_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/collection_screen.dart';
import 'package:mypet/ui/keep_words.dart';

import 'capture_preview.dart';
import 'preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('도감에서 가장 오래된 기억을 골라 고정한 화면을 저장한다', (tester) async {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const screen = ValueKey('synthetic-notebook');
    const favorite = '주인은 강변 벤치에서 노란 공을 던져 주는 걸 좋아한다.';
    final now = DateTime(2026, 11, 24, 13);
    final (db, c, entry) = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      final pet = await db.createPet(
        name: '보리',
        stage: PetStage.puppy,
        furMain: 0xff9c6947,
        furSecond: 0xffedd3a9,
        marking: 0xff57381f,
        now: now,
      );
      await db.addMemory(favorite, now.subtract(const Duration(days: 2)));
      await db.addMemory(
        '비가 오는 날이면 창가에 나란히 앉는다.',
        now.subtract(const Duration(days: 1)),
      );
      await db.addMemory('함께 걷던 길에서 둥근 솔방울을 발견했다.', now);
      return (
        db,
        PetController(db, pet, clock: () => now),
        (await db.recentMemories(3)).last,
      );
    }))!;
    addTearDown(
      () => tester.runAsync(() async {
        await c.settled;
        c.dispose();
        await db.close();
      }),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildC3Theme(),
          home: Scaffold(body: CollectionScreen(controller: c)),
        ),
      ),
    );
    Future<void> paint() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    await tester.tap(find.text('기억 수첩').hitTestable());
    await paint();
    final pin = find.descendant(
      of: find.byKey(ValueKey(entry.id)),
      matching: find.byTooltip('기억 고정'),
    );
    await tester.runAsync(() => tester.tap(pin.hitTestable()));
    await paint();
    expect(find.text('고정 1 / 5'), findsOneWidget);
    expect(find.text(keepWords(favorite)).hitTestable(), findsOneWidget);
    final output = Directory('build/portfolio')..createSync(recursive: true);
    await capturePreview(
      tester,
      find.byKey(screen),
      File('${output.path}/mypet-memory.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.takeException(), isNull);
  });
}
