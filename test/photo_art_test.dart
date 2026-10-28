import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/art/photo_art.dart';

void main() {
  final photo = File('tools/scene_preview/fixtures/synthetic-coat.png');

  test('짧거나 잘린 사진은 색·초상화 대신 null로 반환한다', () {
    final png = img.encodePng(img.Image(width: 8, height: 8));
    final jpeg = img.encodeJpg(img.Image(width: 8, height: 8));
    final samples = [
      for (var size = 0; size < 4; size++) Uint8List(size),
      Uint8List.fromList(png.take(12).toList()),
      Uint8List.fromList(jpeg.take(12).toList()),
    ];
    for (final bytes in samples) {
      expect(extractPetColors(bytes), isNull);
      expect(pixelPortraitPng(bytes), isNull);
    }
  });

  test('정상 합성 사진은 원본 사진 파일 없이도 색과 64칸 초상화를 만든다', () {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(180, 120, 70));
    final bytes = img.encodePng(image);
    expect(extractPetColors(bytes), isNotNull);
    final portrait = pixelPortraitPng(bytes);
    expect(portrait, isNotNull);
    final decoded = img.decodePng(portrait!)!;
    expect(decoded.width, 64);
    expect(decoded.height, 64);
  });

  test('두 색의 합성 견본에서 흰 털과 갈색 무늬를 뽑는다', () async {
    final colors = extractPetColors(await photo.readAsBytes())!;
    int r(int c) => (c >> 16) & 0xFF;
    int g(int c) => (c >> 8) & 0xFF;
    int b(int c) => c & 0xFF;
    expect(
      r(colors.main) + g(colors.main) + b(colors.main),
      greaterThan(540),
      reason: '주 털은 밝아야 한다',
    );
    expect(
      r(colors.marking),
      greaterThan(b(colors.marking) + 40),
      reason: '무늬는 붉은 갈색이어야 한다',
    );
    expect(colors.marking, isNot(colors.main));
  });

  test('초상화는 64×64 PNG로 나온다', () async {
    final png = pixelPortraitPng(await photo.readAsBytes())!;
    final decoded = img.decodePng(png)!;
    expect(decoded.width, 64);
    expect(decoded.height, 64);
  });

  test('그림이 아닌 데이터는 null', () {
    expect(extractPetColors(File('pubspec.yaml').readAsBytesSync()), isNull);
    expect(pixelPortraitPng(File('pubspec.yaml').readAsBytesSync()), isNull);
  });
}
