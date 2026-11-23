// 실제 앱 화면과 합성 펫을 사용해 첫 만남부터 다음 날 일기까지 녹화한다.
// flutter test tools/scene_preview/first_day_showcase_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/main.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/ui/home_screen.dart';

import 'preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('새 펫과 첫날을 보내고 다음 날 저장된 일기를 연다', (tester) async {
    const screen = ValueKey('showcase-screen');
    const permission = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(permission, (_) async => 0);
    addTearDown(() => messenger.setMockMethodCallHandler(permission, null));
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final output = Directory('build/portfolio')..createSync(recursive: true);
    final frames = Directory('${output.path}/frames')
      ..createSync(recursive: true);
    final db = (await tester.runAsync(
      () async => AppDatabase(NativeDatabase.memory()),
    ))!;
    var now = DateTime(2026, 11, 20, 23, 40);
    PetController? controller;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await controller?.settled;
        controller?.dispose();
        await db.close();
      });
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: MypetApp(
          db: db,
          initialPet: null,
          systemPrompt: '',
          diaryPrompt: '',
          ai: null,
          clock: () => now,
          testMode: TestMode(File('${output.path}/synthetic-mode.json')),
          docs: output.path,
        ),
      ),
    );

    Future<void> drain() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    var index = 0;
    final chapters = <(String, int, int)>[];
    Future<void> record(String caption, int count) async {
      final start = index;
      for (var i = 0; i < count; i++) {
        const frame = Duration(milliseconds: 83);
        now = now.add(frame);
        await tester.pump(frame);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screen),
        );
        final number = index.toString().padLeft(4, '0');
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '${frames.path}/frame$number.png',
            ).writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        index++;
      }
      expect(tester.takeException(), isNull);
      chapters.add((caption, start, index - 1));
    }

    await drain();
    await tester.tap(find.widgetWithText(ChoiceChip, '갈색'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '이름'), '보리');
    await drain();
    await record('보리와 처음 만나는 밤', 22);
    await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('건너뛰고 시작')));
    await drain();
    final c = tester.widget<HomeScreen>(find.byType(HomeScreen)).controller;
    controller = c;
    // 클라우드에 합성 입력을 보내지 않고 제품의 로컬 반응과 일기 경로를 보여 준다.
    c.brain = null;
    await record('첫 만남  ·  문 앞에서 냄새를 맡고 다가와요', 64);
    await tester.tap(find.text('밥 주기'));
    await record('첫 식사  ·  보리가 밥을 먹어요', 58);
    await tester.runAsync(() => c.settled);
    await tester.tap(find.text('일기').hitTestable());
    await tester.pump();
    await tester.runAsync(() => tester.tap(find.text('오늘 미리 보기')));
    await drain();
    expect(find.text('오늘 지금까지'), findsOneWidget);
    expect(await tester.runAsync(() => db.allDiaries()), isEmpty);
    await record('그날 밤  ·  오늘 있었던 일을 미리 봐요', 40);
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('집').hitTestable());
    await tester.pump();
    await tester.runAsync(() async {
      c.sleepApp();
      await c.settled;
      now = DateTime(2026, 11, 21, 9);
      c.wake();
      await c.settled;
      final entry = (await db.allDiaries()).single;
      expect(entry.content, contains('처음으로 주인 냄새를 맡았다'));
      expect(entry.content, contains('밥을 줬다'));
    });
    await drain();
    await record('다음 날 아침  ·  테스트 시계를 앞당겼어요', 26);
    await tester.tap(find.text('일기').hitTestable());
    await drain();
    await record('다시 펼친 일기  ·  어제의 첫 만남과 밥 한 끼', 42);

    await tester.runAsync(() async {
      final filters = ['pad=iw:ih+72:0:0:color=0x38312c'];
      for (final (n, chapter) in chapters.indexed) {
        final (caption, start, end) = chapter;
        final file = File('${frames.path}/caption$n.txt');
        await file.writeAsString(caption);
        filters.add(
          "drawtext=fontfile=assets/fonts/GowunDodum-Regular.ttf:"
          "textfile='${file.path.replaceAll('\\', '/')}':fontcolor=white:fontsize=23:"
          "x=(w-tw)/2:y=h-48:enable='between(n,$start,$end)'",
        );
      }
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-framerate',
        '12',
        '-i',
        '${frames.path}/frame%04d.png',
        '-frames:v',
        '$index',
        '-vf',
        filters.join(','),
        '-c:v',
        'libx264',
        '-threads',
        '1',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        '${output.path}/mypet-first-day.mp4',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
