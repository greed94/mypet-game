import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/ui/c3/c3_theme.dart';
import 'package:mypet/ui/photo_framing_screen.dart';
import 'package:mypet/ui/shape_picker.dart';

final _dog = File('tools/scene_preview/fixtures/synthetic-beagle.jpg');

void main() {
  setUp(ShapePicker.resetCache);
  test('가로 사진의 테두리는 네 모서리에서 사진 밖으로 나가지 않는다', () {
    for (final (w, h) in [(1, 1), (900, 600), (380, 1100), (9, 2)]) {
      for (final point in [-2.0, 0.0, .5, 1.0, 3.0]) {
        for (final zoom in [.4, 1.0, 2.0, 3.0, 7.0]) {
          final frame = PhotoFrame(
            x: point,
            y: 1 - point,
            zoom: zoom,
          ).fitted(w, h);
          final crop = frame.square(w, h);
          expect(crop.left, greaterThanOrEqualTo(0));
          expect(crop.top, greaterThanOrEqualTo(0));
          expect(crop.left + crop.side, lessThanOrEqualTo(w));
          expect(crop.top + crop.side, lessThanOrEqualTo(h));
          expect(crop.side, greaterThanOrEqualTo(1));
        }
      }
    }
  });

  test('촬영 방향을 먼저 바로잡고 편집 사진과 저장용 64픽셀 초상화에서 원본 메타데이터를 뺀다', () {
    final photo = img.Image(width: 60, height: 30);
    img.fill(photo, color: img.ColorRgb8(80, 45, 32));
    photo.exif.imageIfd.orientation = 6;
    photo.exif.imageIfd.make = 'synthetic-private-camera';
    final jpeg = img.encodeJpg(photo);
    expect(img.decodeJpg(jpeg)!.exif.imageIfd.make, contains('private'));
    final source = preparePetPhoto(jpeg)!;
    expect((source.width, source.height), (30, 60));
    for (final bytes in [
      source.pixels,
      source.initial.portrait,
      pixelPortraitPng(jpeg)!,
    ]) {
      final copy = img.decodePng(bytes)!;
      expect(copy.exif.imageIfd.make, isNull);
      expect(copy.exif.imageIfd.orientation, isNull);
    }
    expect(img.decodePng(source.initial.portrait)!.width, 64);
    expect(preparePetPhoto(Uint8List.fromList([0x12, 0x00])), isNull);
  });

  test('16비트 PNG의 실제 채널을 정규화하고 투명 팔레트의 숨은 RGB는 버린다', () {
    final high = img.Image(
      width: 32,
      height: 32,
      format: img.Format.uint16,
      numChannels: 4,
    );
    for (final p in high) {
      p.setRgba(54000, 30000, 9000, 65535);
    }
    final converted = img
        .decodePng(preparePetPhoto(img.encodePng(high))!.pixels)!
        .getPixel(16, 16);
    expect(converted.r, closeTo(210, 2));
    expect(converted.g, closeTo(117, 2));
    expect(converted.b, closeTo(35, 2));
    expect(converted.a, 255);

    PreparedPetPhoto indexed(int secret) {
      final palette = img.PaletteUint8(256, 4)
        ..setRgba(0, secret, 20, 255 - secret, 0)
        ..setRgba(1, 189, 110, 28, 255);
      final image = img.Image(
        width: 32,
        height: 32,
        withPalette: true,
        palette: palette,
      );
      for (var y = 8; y < 24; y++) {
        for (var x = 8; x < 24; x++) {
          image.setPixelIndex(x, y, 1);
        }
      }
      return preparePetPhoto(img.encodePng(image))!;
    }

    final a = indexed(240), b = indexed(10);
    final clean = img.decodePng(a.pixels)!;
    final hidden = clean.getPixel(1, 1), center = clean.getPixel(16, 16);
    expect([hidden.r, hidden.g, hidden.b, hidden.a], [0, 0, 0, 0]);
    expect([center.r, center.g, center.b, center.a], [189, 110, 28, 255]);
    expect(a.pixels, orderedEquals(b.pixels));
    expect(a.initial.portrait, orderedEquals(b.initial.portrait));
    expect(a.initial.colors.main, b.initial.colors.main);
  });

  test('전부 투명하면 거절하고 한쪽에만 있는 강아지는 보이는 영역에서 시작한다', () {
    final transparent = img.Image(width: 160, height: 32, numChannels: 4);
    expect(preparePetPhoto(img.encodePng(transparent)), isNull);
    img.fillRect(
      transparent,
      x1: 140,
      y1: 6,
      x2: 159,
      y2: 25,
      color: img.ColorRgba8(142, 88, 44, 255),
    );
    final source = preparePetPhoto(img.encodePng(transparent))!;
    expect(source.initialFrame.x, greaterThan(.7));
    expect(
      () => renderPetPhoto((
        pixels: source.pixels,
        frame: const PhotoFrame(x: .2, y: .5),
      )),
      throwsA(isA<EmptyPhotoArea>()),
    );
    expect(source.initial.portrait, isNotEmpty);
    final corner = img.Image(width: 64, height: 64, numChannels: 4)
      ..setPixelRgba(0, 0, 120, 85, 40, 255);
    expect(
      preparePetPhoto(img.encodePng(corner))!.initial.portrait,
      isNotEmpty,
    );
  });

  test('중앙이 비어 있으면 거의 안 보이는 먼지 한 점보다 충분히 보이는 피사체로 시작한다', () {
    final photo = img.Image(width: 768, height: 256, numChannels: 4)
      ..setPixelRgba(0, 0, 30, 30, 30, 1);
    img.fillRect(
      photo,
      x1: 600,
      y1: 72,
      x2: 706,
      y2: 180,
      color: img.ColorRgba8(154, 90, 42, 255),
    );
    final visible = preparePetPhoto(img.encodePng(photo));
    expect(visible, isNotNull);
    expect(visible!.initialFrame.x, greaterThan(.65));
    expect(visible.initial.portrait, isNotEmpty);
  });

  test('투명 배경 위의 흰 털을 줄여도 털색과 초상화에 검은 윤곽이 생기지 않는다', () {
    final source = img.Image(width: 128, height: 128, numChannels: 4);
    for (var y = 0; y < 128; y += 2) {
      for (var x = 0; x < 128; x += 2) {
        source.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
    final photo = preparePetPhoto(img.encodePng(source))!;
    expect(photo.initial.colors.main, 0xffffffff);
    final center = img.decodePng(photo.initial.portrait)!.getPixel(32, 32);
    expect(center.r, greaterThan(245));
    expect(center.g, greaterThan(240));
  });

  testWidgets('선택한 강아지 그림을 준비할 때는 원본과 초상화가 떠도 확정하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(392, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = preparePetPhoto(
      img.encodePng(img.Image(width: 32, height: 32)),
    )!;
    const asset = 'assets/sprites/pug_puppy.png';
    final sprite = (await tester.runAsync(() => File(asset).readAsBytes()))!;
    final gate = (await tester.runAsync(() async => Completer<ByteData?>()))!;
    final messenger = tester.binding.defaultBinaryMessenger;
    var attempts = 0;
    messenger.setMockMessageHandler('flutter/assets', (data) async {
      if (data != null &&
          utf8.decode(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              ) ==
              asset) {
        return ++attempts == 1 ? gate.future : ByteData.sublistView(sprite);
      }
      return messenger.delegate.send('flutter/assets', data);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Scaffold(
          body: PhotoFrameButton(
            shape: 'pug',
            photo: centerPetPhoto(source),
            onApply: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('얼굴 위치 맞추기'));
    await tester.pumpAndSettle();
    Future<void> draw() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 8)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    final confirm = find.widgetWithText(FilledButton, '이 영역 사용');
    for (var i = 0; i < 15; i++) {
      await draw();
    }
    expect(attempts, 1);
    final whileLoading = tester.widget<FilledButton>(confirm).onPressed;
    await tester.runAsync(() async {
      gate.complete(null);
      await pumpEventQueue();
    });
    for (
      var i = 0;
      i < 100 && tester.widget<FilledButton>(confirm).onPressed == null;
      i++
    ) {
      await draw();
    }
    expect(whileLoading, isNull);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    final retry = find.widgetWithText(TextButton, '강아지 그림 다시 읽기');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry.hitTestable());
    await tester.pump();
    for (
      var i = 0;
      i < 100 && tester.widget<FilledButton>(confirm).onPressed == null;
      ++i
    ) {
      await draw();
    }
    expect(attempts, 2);
    expect(retry, findsNothing);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('오른쪽의 가상 강아지를 고르면 소파 대신 실제 갈색 털과 다른 초상화가 나온다', () async {
    final source = preparePetPhoto(await _dog.readAsBytes())!;
    final centered = source.initial;
    final selected = renderPetPhoto((
      pixels: source.pixels,
      frame: const PhotoFrame(x: .78, y: .44, zoom: 2.0),
    ));
    expect(listEquals(selected.portrait, centered.portrait), isFalse);
    final fur = Color(selected.colors.main).toARGB32();
    final red = (fur >> 16) & 255, blue = fur & 255;
    expect(red, greaterThan(blue + 20));
    final sofa = Color(centered.colors.main).toARGB32();
    expect((sofa >> 16) & 255, lessThan(sofa & 255));
  });

  testWidgets('작은 원본에서 손가락의 짧은 연속 이동도 합쳐서 얼굴 위치에 반영한다', (tester) async {
    final pixels = img.Image(width: 64, height: 64);
    img.fill(pixels, color: img.ColorRgb8(135, 91, 46));
    final source = preparePetPhoto(img.encodePng(pixels))!;
    EditablePetPhoto? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Scaffold(
          body: PhotoFrameButton(
            photo: centerPetPhoto(source),
            onApply: (p) => result = p,
          ),
        ),
      ),
    );
    await tester.tap(find.text('얼굴 위치 맞추기'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2.0);
    await tester.pump();
    final picture = find.byKey(const ValueKey('pet-photo-frame'));
    final box = tester.getRect(picture);
    final gesture = await tester.startGesture(box.center);
    // 스크롤과의 제스처 판별을 먼저 끝낸 뒤, 1픽셀 이동의 누적만 잰다.
    await gesture.moveBy(const Offset(42, 0));
    await tester.pump();
    final region = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '원본 사진의 선택 영역',
    );
    final value = tester.widget<Semantics>(region).properties.value!;
    final startPercent = int.parse(
      RegExp(r'가로 (\d+)%').firstMatch(value)!.group(1)!,
    );
    for (var i = 0; i < 52; i++) {
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    final confirm = find.widgetWithText(FilledButton, '이 영역 사용');
    for (
      var i = 0;
      i < 100 && tester.widget<FilledButton>(confirm).onPressed == null;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    expect(find.bySemanticsLabel(RegExp('주 털, .*RGB')), findsOneWidget);
    await tester.tap(confirm.hitTestable());
    await tester.pumpAndSettle();
    expect(result!.selection.frame.x * 100, greaterThan(startPercent + 5));
    expect(result!.selection.frame.y, closeTo(.5, .015));
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 창에서 터치와 이동 버튼으로 영역을 고르고 실제 최신 미리보기를 확정한다', (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = (await tester.runAsync(
      () async => preparePetPhoto(await _dog.readAsBytes()),
    ))!;
    EditablePetPhoto? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildC3Theme(),
        home: Scaffold(
          body: PhotoFrameButton(
            photo: centerPetPhoto(source),
            onApply: (p) => returned = p,
          ),
        ),
      ),
    );
    await tester.tap(find.text('얼굴 위치 맞추기'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(2.0);
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('pet-photo-frame')));
    await tester.tapAt(
      Offset(rect.left + rect.width * .75, rect.top + rect.height * .44),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('오른쪽으로').hitTestable());
    await tester.pump(const Duration(milliseconds: 150));
    final confirm = find.widgetWithText(FilledButton, '이 영역 사용');
    for (
      var i = 0;
      i < 100 && tester.widget<FilledButton>(confirm).onPressed == null;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 12)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm.hitTestable());
    await tester.pumpAndSettle();
    expect(returned, isNotNull);
    final chosen = returned!.selection;
    expect(chosen.frame.x, closeTo(.80, .012));
    expect(chosen.frame.y, closeTo(.44, .012));
    final expected = renderPetPhoto((
      pixels: source.pixels,
      frame: chosen.frame,
    ));
    expect(chosen.look.portrait, orderedEquals(expected.portrait));
    expect(tester.takeException(), isNull);
  });
}
