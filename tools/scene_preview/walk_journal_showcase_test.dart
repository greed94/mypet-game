// flutter test tools/scene_preview/walk_journal_showcase_test.dart
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/diary_screen.dart';
import 'package:mypet/ui/walk_card.dart';

import 'capture_preview.dart';
import 'preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('일기에서 함께 걸은 산책을 다시 열어 원래 지도를 캡처한다', (tester) async {
    const key = ValueKey('walk-journal-review');
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, c) = (await tester.runAsync(() async {
      final db = AppDatabase(NativeDatabase.memory());
      var now = DateTime(2026, 11, 21, 15, 24);
      final pet = await db.createPet(
        name: '보리',
        stage: PetStage.puppy,
        furMain: 0xff9c6947,
        furSecond: 0xffedd3a9,
        marking: 0xff57381f,
        now: now.subtract(const Duration(days: 3)),
      );
      final c = PetController(db, pet, random: Random(7), clock: () => now);
      // PC에서 시간을 앞당기고 걸음 수를 넣되 기록과 지도는 실제 산책 종료 코드로 만든다.
      for (final (days, minutes, steps, sniffs) in [
        (0, 0, 18, 0),
        (1, 12, 930, 1),
        (1, 23, 2140, 3),
      ]) {
        now = now.add(Duration(days: days));
        expect(c.startWalk(), isTrue);
        c.updateWalkSteps(steps);
        c.walkSniffs = sniffs;
        now = now.add(Duration(minutes: minutes));
        c.endWalk();
        await c.settled;
      }
      return (db, c);
    }))!;
    addTearDown(
      () => tester.runAsync(() async {
        c.dispose();
        await db.close();
      }),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildC3Theme(),
          home: Scaffold(
            body: DiaryScreen(controller: c, db: db),
          ),
        ),
      ),
    );
    Future<void> paint() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 12)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    await paint();
    await tester.tap(find.text('산책 기록').hitTestable());
    await paint();
    final output = Directory('build/portfolio')..createSync(recursive: true);
    final list = File('${output.path}/mypet-walk-list.png');
    final card = File('${output.path}/mypet-walk-map.png');
    expect(find.text('산책 지도 보기'), findsNWidgets(2));
    await capturePreview(tester, find.byKey(key), list);
    await tester.tap(find.text('산책 지도 보기').first.hitTestable());
    await paint();
    expect(
      find.descendant(
        of: find.byType(WalkMap),
        matching: find.textContaining('2,140걸음'),
      ),
      findsOneWidget,
    );
    await capturePreview(tester, find.byKey(key), card);
    await tester.runAsync(() async {
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        list.path,
        '-i',
        card.path,
        '-filter_complex',
        'hstack=inputs=2',
        '-frames:v',
        '1',
        '${output.path}/mypet-walk-journal.png',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.takeException(), isNull);
  });
}
