import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/game/palette.dart';

void main() {
  test('키 색만 펫 색으로 바뀌고 외곽선과 투명은 그대로다', () {
    final rgba = Uint8List.fromList([
      255, 0, 0, 255, // 주 털
      128, 0, 0, 255, // 주 털 그림자
      0, 255, 0, 255, // 보조 털
      0, 0, 255, 255, // 포인트
      255, 255, 0, 255, // 무늬
      43, 29, 22, 255, // 외곽선
      255, 0, 0, 0, // 투명
    ]);
    final out = swapPalette(
      rgba,
      main: 0xFFC48C54,
      second: 0xFFF4E2C4,
      accent: 0xFFD64040,
      marking: 0xFF914F28,
    );
    expect(out.sublist(0, 4), [0xC4, 0x8C, 0x54, 255]);
    expect(out.sublist(4, 8), [167, 119, 71, 255]);
    expect(out.sublist(8, 12), [0xF4, 0xE2, 0xC4, 255]);
    expect(out.sublist(12, 16), [0xD6, 0x40, 0x40, 255]);
    expect(out.sublist(16, 20), [0x91, 0x4F, 0x28, 255]);
    expect(out.sublist(20, 24), [43, 29, 22, 255]);
    expect(out.sublist(24, 28), [255, 0, 0, 0]);
  });

  test('반투명 키 색은 바꾼 뒤 알파를 곱한다', () {
    final rgba = Uint8List.fromList([255, 0, 0, 128]);
    final out = swapPalette(
      rgba,
      main: 0xFFC48C54,
      second: 0xFFF4E2C4,
      accent: 0xFFD64040,
      marking: 0xFF914F28,
    );
    expect(out, [98, 70, 42, 128]);
  });

  test('입 위치 표시 픽셀은 프레임 좌표로 읽고 투명하게 지운다', () {
    // 가로 2프레임(프레임 2×2), 세로 1줄. 두 번째 프레임의 (1, 0)에 표시.
    final rgba = Uint8List(4 * 2 * 4);
    final i = (0 * 4 + 3) * 4;
    rgba.setAll(i, [255, 0, 255, 255]);
    final anchors = takeMouthAnchors(rgba, 4, 2);
    expect(anchors, {(0, 1): (1, 0)});
    expect(rgba.sublist(i, i + 4), [0, 0, 0, 0]);
  });
}
