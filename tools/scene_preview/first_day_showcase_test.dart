// 실제 앱 화면과 합성 펫을 사용해 첫 만남부터 다음 날 일기까지 녹화한다.
// flutter test tools/scene_preview/first_day_showcase_test.dart
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/game/pet_game.dart';
import 'package:mypet/main.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/services/sfx.dart';
import 'package:mypet/services/test_mode.dart';
import 'package:mypet/ui/home_screen.dart';

import 'capture_preview.dart';
import 'preview_fonts.dart';

// 앱이 실제로 재생을 시작한 프레임에 그 소리 파일을 얹는다.
class _RecordingPlayer extends Fake implements AudioPlayer {
  _RecordingPlayer(this.onStart);
  final void Function() onStart;

  @override
  Future<void> stop() async {}

  @override
  Future<void> resume() async => onStart();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('새 펫과 첫날을 보내고 다음 날 저장된 일기를 연다', (tester) async {
    const screen = ValueKey('showcase-screen');
    const permission = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const audio = MethodChannel('mypet/audio');
    const fps = 12;
    var index = 0;
    int? recordingFrame;
    final sounds = <(String, int)>[];
    final effects = Sfx(
      loadPlayer: (name) async => _RecordingPlayer(() {
        final frame = recordingFrame;
        if (frame != null) sounds.add((name, frame));
      }),
    );
    final messenger = tester.binding.defaultBinaryMessenger;
    const preferences = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    messenger.setMockMethodCallHandler(preferences, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(preferences, null));
    messenger.setMockMethodCallHandler(audio, (_) async => 2);
    addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
    await tester.runAsync(effects.init);
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
          effects: effects,
          clock: () => now,
          testMode: TestMode(File('${output.path}/synthetic-mode.json')),
          docs: output.path,
        ),
      ),
    );

    Future<void> drain({bool advance = true}) async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(
          advance ? const Duration(milliseconds: 16) : Duration.zero,
        );
      }
    }

    final chapters = <(String, int, int)>[];
    Future<void> record(
      String caption,
      int count, {
      String? expectedBubble,
    }) async {
      final start = index;
      for (var i = 0; i < count; i++) {
        recordingFrame = index;
        // 첫 화면은 터치 순간이다. 이후에는 영상의 12fps와 같은 간격으로 시계를 보낸다.
        final micros = i == 0
            ? 0
            : index * 1000000 ~/ fps - (index - 1) * 1000000 ~/ fps;
        final elapsed = Duration(microseconds: micros);
        now = now.add(elapsed);
        await tester.pump(elapsed);
        if (expectedBubble != null) {
          expect(
            controller!.bubble,
            expectedBubble,
            reason: '재회 장면 $index 프레임',
          );
        }
        final number = index.toString().padLeft(4, '0');
        await capturePreview(
          tester,
          find.byKey(screen),
          File('${frames.path}/frame$number.png'),
        );
        index++;
      }
      expect(tester.takeException(), isNull);
      recordingFrame = null;
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
    recordingFrame = index;
    await tester.runAsync(() => tester.tap(find.text('건너뛰고 시작')));
    await drain(advance: false);
    final c = tester.widget<HomeScreen>(find.byType(HomeScreen)).controller;
    controller = c;
    // 클라우드에 합성 입력을 보내지 않고 제품의 로컬 반응과 일기 경로를 보여 준다.
    c.brain = null;
    await record('첫 만남  ·  문 앞에서 냄새를 맡고 다가와요', 53);
    recordingFrame = index;
    await tester.tap(find.text('밥 주기'));
    await record('첫 식사  ·  보리가 밥을 먹어요', 45);
    await tester.runAsync(() => c.settled);
    await tester.tap(find.text('일기').hitTestable());
    await drain();
    expect(find.text('처음 만남'), findsOneWidget);
    expect(find.text('밥 먹기'), findsOneWidget);
    final livePage = File('${output.path}/mypet-diary-first-page.png');
    await capturePreview(tester, find.byKey(screen), livePage);
    await tester.runAsync(() => tester.tap(find.text('오늘 미리 보기')));
    await drain();
    expect(find.text('오늘 지금까지'), findsOneWidget);
    expect(await tester.runAsync(() => db.allDiaries()), isEmpty);
    await record('그날 밤  ·  오늘 있었던 일을 미리 봐요', 36);
    await tester.tap(find.text('닫기'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('집').hitTestable());
    await tester.pump();
    recordingFrame = index;
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
    await drain(advance: false);
    await record('다음 날 아침  ·  테스트 시계를 앞당겼어요', 16);
    expect(find.textContaining('2일째 함께'), findsOneWidget);
    final room = find.byType(GameWidget<PetGame>);
    final game = tester.widget<GameWidget<PetGame>>(room).game!;
    final dog =
        tester.getTopLeft(room) +
        Offset(game.floorX(c.petX), game.petBaseline - 12 * game.pixelScale);
    recordingFrame = index;
    await tester.tapAt(dog);
    await drain(advance: false);
    const reunionLine = '킁… 어제 밥 주던 손 냄새다!';
    expect(c.bubble, reunionLine);
    expect(
      await tester.runAsync(() => db.eventsOfKind('first_recognition')),
      hasLength(1),
    );
    await capturePreview(
      tester,
      find.byKey(screen),
      File('${output.path}/mypet-first-return.png'),
    );
    await record('쓰다듬자 어제 밥 주던 손을 알아봐요', 44, expectedBubble: reunionLine);
    await tester.tap(find.text('일기').hitTestable());
    await drain();
    await tester.tap(find.text('그날의 발자국').hitTestable());
    await drain();
    expect(find.text('함께한 첫날'), findsOneWidget);
    expect(find.text('밥 먹기'), findsOneWidget);
    final savedPage = File('${output.path}/mypet-diary-saved-page.png');
    await capturePreview(tester, find.byKey(screen), savedPage);
    await record('다시 펼친 일기  ·  어제의 만남과 식사 시각', 36);

    await tester.tap(find.text('집').hitTestable());
    await drain();
    final roomShot = File('${output.path}/mypet-room.png');
    final mapShot = File('${output.path}/mypet-map.png');
    await capturePreview(tester, find.byKey(screen), roomShot);
    await tester.tap(find.text('동네 지도').hitTestable());
    await drain();
    expect(find.text('어디 갈까?'), findsOneWidget);
    await capturePreview(tester, find.byKey(screen), mapShot);

    await tester.tap(find.bySemanticsLabel('지도 닫기'));
    await drain();
    tester.view.physicalSize = const Size(320, 420);
    await drain();
    expect(find.text('밥 주기').hitTestable(), findsOneWidget);
    await capturePreview(
      tester,
      find.byKey(screen),
      File('${output.path}/mypet-compact-room.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final spread = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        roomShot.path,
        '-i',
        mapShot.path,
        '-filter_complex',
        'hstack=inputs=2',
        '-frames:v',
        '1',
        '${output.path}/mypet-neighborhood.png',
      ]);
      expect(spread.exitCode, 0, reason: spread.stderr.toString());

      final diarySpread = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        livePage.path,
        '-i',
        savedPage.path,
        '-filter_complex',
        'hstack=inputs=2',
        '-frames:v',
        '1',
        '${output.path}/mypet-diary-trail.png',
      ]);
      expect(diarySpread.exitCode, 0, reason: diarySpread.stderr.toString());

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
      final cues = sounds.where((sound) => sound.$2 < index).toList();
      expect(cues.map((event) => event.$1), containsAll(['sniff', 'crunch']));
      final audioFilters = <String>[];
      for (final (i, event) in cues.indexed) {
        final delayMs = (event.$2 * 1000 / fps).round();
        audioFilters.add('[${i + 1}:a]adelay=$delayMs:all=1[a$i]');
      }
      final inputs = [for (var i = 0; i < cues.length; i++) '[a$i]'].join();
      final seconds = (index / fps).toStringAsFixed(3);
      audioFilters.add(
        '${inputs}amix=inputs=${cues.length}:normalize=0,volume=0.8,apad,atrim=duration=$seconds[sound]',
      );
      await File('${output.path}/first-day-sound.tsv').writeAsString(
        [
          'frame\tasset',
          for (final (name, frame) in cues) '$frame\t$name',
        ].join('\n'),
      );
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-framerate',
        '$fps',
        '-i',
        '${frames.path}/frame%04d.png',
        for (final (name, _) in cues) ...['-i', 'assets/sfx/$name.wav'],
        '-filter_complex',
        audioFilters.join(';'),
        '-map',
        '0:v:0',
        '-map',
        '[sound]',
        '-t',
        seconds,
        '-vf',
        filters.join(','),
        '-c:v',
        'libx264',
        '-threads',
        '1',
        '-crf',
        '18',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-ar',
        '48000',
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
