import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/main.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/ui/home_screen.dart';

import 'capture_preview.dart';
import 'preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    '가상 강아지 사진의 오른쪽 얼굴을 고르고 저장된 털색과 초상화를 다시 연다',
    (tester) async {
      tester.view.physicalSize = const Size(392, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = File(
        'tools/scene_preview/fixtures/synthetic-beagle.jpg',
      ).absolute;
      final output = Directory('build/portfolio/photo-framing')
        ..createSync(recursive: true);
      final dbFile = File(
        '${output.path}/synthetic-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(picker, (_) async => fixture.path);
      messenger.setMockMethodCallHandler(
        paths,
        (_) async => output.absolute.path,
      );
      messenger.setMockMethodCallHandler(permissions, (_) async => 0);
      addTearDown(() {
        for (final channel in [picker, paths, permissions]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final db = AppDatabase(NativeDatabase(dbFile));
      const surface = ValueKey('photo-showcase');
      await tester.pumpWidget(
        RepaintBoundary(
          key: surface,
          child: MypetApp(
            db: db,
            initialPet: null,
            systemPrompt: '',
            diaryPrompt: '',
            ai: null,
            clock: () => DateTime(2026, 11, 24, 10),
            testMode: TestMode(File('${output.path}/mode.json')),
            docs: output.absolute.path,
          ),
        ),
      );
      Future<void> drain([int ticks = 12]) async {
        for (var i = 0; i < ticks; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 12)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 160 && !done(); i++) {
          await drain(1);
        }
        expect(done(), isTrue);
      }

      await drain();
      await tester.runAsync(() => tester.tap(find.text('사진으로 만들기')));
      await until(() => find.text('얼굴 위치 맞추기').evaluate().isNotEmpty);
      final shape = find.text('리트리버·비글·코커');
      await tester.ensureVisible(shape);
      await tester.tap(shape.hitTestable());
      await tester.pump();
      final edit = find.text('얼굴 위치 맞추기');
      await tester.ensureVisible(edit);
      await tester.tap(edit.hitTestable());
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, '이 영역 사용');
      await until(() => tester.widget<FilledButton>(confirm).onPressed != null);
      await drain();
      final original = File('${output.path}/center.png');
      await capturePreview(tester, find.byKey(surface), original);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(2.0);
      await tester.pump();
      final rect = tester.getRect(
        find.byKey(const ValueKey('pet-photo-frame')),
      );
      await tester.tapAt(
        Offset(rect.left + rect.width * .78, rect.top + rect.height * .44),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await until(() => tester.widget<FilledButton>(confirm).onPressed != null);
      await drain();
      final framed = File('${output.path}/face.png');
      await capturePreview(tester, find.byKey(surface), framed);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '이름'), '호두');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '다음').hitTestable());
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('건너뛰고 시작')));
      await until(() => find.byType(HomeScreen).evaluate().isNotEmpty);
      final c = tester.widget<HomeScreen>(find.byType(HomeScreen)).controller;
      await tester.runAsync(() => c.settled);
      await drain();
      final homeShot = File('${output.path}/home.png');
      await capturePreview(tester, find.byKey(surface), homeShot);
      final pet = (await tester.runAsync(() => db.loadPet()))!;
      expect(pet.name, '호두');
      expect(pet.shape, 'retriever');
      final selectedSource = (await tester.runAsync(
        () async => preparePetPhoto(await fixture.readAsBytes()),
      ))!;
      final expected = renderPetPhoto((
        pixels: selectedSource.pixels,
        frame: const PhotoFrame(x: .78, y: .44, zoom: 2.0),
      ));
      // 실제 위젯 좌표에서 고른 점은 이미지 한 픽셀 안에서 반올림될 수 있다.
      final mainColor = pet.furMain;
      expect((mainColor >> 16) & 255, greaterThan((mainColor & 255) + 20));
      expect(
        (mainColor >> 16) & 255,
        closeTo((expected.colors.main >> 16) & 255, 20),
      );
      final kept = File(pet.portraitPath!);
      final firstPixels = await tester.runAsync(() => kept.readAsBytes());
      expect(firstPixels, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() async {
        await c.settled;
        if (!c.isDisposed) c.dispose();
        await db.close();
        final reopened = AppDatabase(NativeDatabase(dbFile));
        try {
          final again = (await reopened.loadPet())!;
          expect(again.furMain, mainColor);
          expect(
            await File(again.portraitPath!).readAsBytes(),
            orderedEquals(firstPixels!),
          );
        } finally {
          await reopened.close();
        }
        final encoded = await Process.run('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-y',
          '-i',
          original.path,
          '-i',
          framed.path,
          '-i',
          homeShot.path,
          '-filter_complex',
          'hstack=inputs=3',
          '-frames:v',
          '1',
          '${output.parent.path}/mypet-photo-framing.png',
        ]);
        expect(encoded.exitCode, 0, reason: encoded.stderr.toString());
      });
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
