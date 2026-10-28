import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/c3/c3_gallery.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/c3/sticker_card.dart';
import 'package:mypet/ui/c3/thought_cloud.dart';

const _shotKey = ValueKey('c3-shot');

Future<void> _loadFonts() async {
  const families = {
    C3Fonts.jua: ['Jua-Regular.ttf'],
    C3Fonts.gowun: ['GowunDodum-Regular.ttf'],
    C3Fonts.gaegu: ['Gaegu-Regular.ttf', 'Gaegu-Bold.ttf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

// 테스트 환경에서 Image.asset 은 실제 비동기 디코딩이 끝나야 그려진다.
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

// 360×879 화면을 3배로 떠서 shots/ 에 남긴다 (목업 스크린샷과 같은 1080×2637).
Future<void> _shot(WidgetTester tester, String name) async {
  await _decodeImages(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory('shots').createSync();
    File('shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('C3Gallery 가 360×879 에서 예외·넘침 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2637);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 84, bottom: 144);
    addTearDown(tester.view.reset);
    // 테스트 기본값은 그림자를 흐림 없이 그린다. 목업과 비교하려고 실제처럼 흐리게 한다.
    debugDisableShadows = false;
    try {
      await _runGallery(tester);
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('흰 카드 다이얼로그: 본문이 길어도 넘치지 않고 버튼이 남는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showC3Dialog<void>(
              context,
              title: '오늘 지금까지',
              body: Column(
                children: [
                  for (var i = 0; i < 30; i++) Text('긴 일기 줄 $i'),
                  const SizedBox(height: 300),
                ],
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('확인'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 지금까지'), findsNothing);
  });

  test('paintThoughtCloud 는 BuildContext 없이 캔버스에 그린다', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const body = Rect.fromLTWH(10, 10, 160, 70);
    paintThoughtCloud(canvas, body, const Offset(140, 120), aiTag: true);
    paintThoughtCloud(canvas, body, const Offset(20, 90));
    recorder.endRecording().dispose();
  });
}

Future<void> _runGallery(WidgetTester tester) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildC3Theme(),
        home: const C3Gallery(),
      ),
    ),
  );
  expect(find.text('콩이'), findsOneWidget);
  await _shot(tester, 'c3_gallery');

  await tester.tap(find.text('일기'));
  await tester.pump();
  await _shot(tester, 'c3_gallery_diary');

  await tester.ensureVisible(find.text('다이얼로그 보기'));
  await tester.tap(find.text('다이얼로그 보기'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('콩이가 기다렸어요'), findsOneWidget);
  await _shot(tester, 'c3_gallery_dialog');
  await tester.tap(find.text('확인'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text('콩이가 기다렸어요'), findsNothing);

  await tester.tap(find.text('도감'));
  await tester.pump();
  await _shot(tester, 'c3_gallery_book');

  await tester.tap(find.text('집'));
  await tester.pump();
  await tester.tap(find.text('밥 주기'));
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}
