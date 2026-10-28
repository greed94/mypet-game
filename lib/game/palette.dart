import 'dart:typed_data';

/// AGENTS.md 스프라이트 규격의 키 색 (0xRRGGBB).
const keyMain = 0xFF0000;
const keyShadow = 0x800000;
const keySecond = 0x00FF00;
const keyAccent = 0x0000FF;
const keyMarking = 0xFFFF00;

/// 입 위치 표시 픽셀. 물고 다니는 물건을 이 자리에 그린다.
const keyMouth = 0xFF00FF;

/// 색은 0xAARRGGBB. 그림자 키 색은 주 털을 어둡게 해서 채운다.
Uint8List swapPalette(
  Uint8List rgba, {
  required int main,
  required int second,
  required int accent,
  required int marking,
}) {
  final map = {
    keyMain: main,
    keyShadow: _darken(main, 0.85),
    keySecond: second,
    keyAccent: accent,
    keyMarking: marking,
  };
  final out = Uint8List.fromList(rgba);
  for (var i = 0; i + 3 < out.length; i += 4) {
    final a = out[i + 3];
    if (a == 0) continue;
    final to = map[(out[i] << 16) | (out[i + 1] << 8) | out[i + 2]];
    if (to != null) {
      out[i] = (to >> 16) & 0xFF;
      out[i + 1] = (to >> 8) & 0xFF;
      out[i + 2] = to & 0xFF;
    }
    // 읽을 때는 키 색을 정확히 맞추려고 straight 알파로 읽지만,
    // decodeImageFromPixels는 premultiplied를 기대하므로 반투명 픽셀은 여기서 곱해 준다.
    if (a < 255) {
      for (var c = i; c < i + 3; c++) {
        out[c] = (out[c] * a + 127) ~/ 255;
      }
    }
  }
  return out;
}

int _darken(int argb, double k) {
  final r = (((argb >> 16) & 0xFF) * k).round();
  final g = (((argb >> 8) & 0xFF) * k).round();
  final b = ((argb & 0xFF) * k).round();
  return (argb & 0xFF000000) | (r << 16) | (g << 8) | b;
}

/// 시트에서 프레임마다 입 위치(프레임 안 좌표)를 찾고, 표시 픽셀은 투명으로 지운다.
/// 키는 (줄, 칸). 표시가 없는 프레임은 결과에 없다.
Map<(int, int), (int, int)> takeMouthAnchors(
  Uint8List rgba,
  int width,
  int frame,
) {
  final anchors = <(int, int), (int, int)>{};
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] == 0) continue;
    if ((rgba[i] << 16 | rgba[i + 1] << 8 | rgba[i + 2]) != keyMouth) continue;
    final p = i ~/ 4, x = p % width, y = p ~/ width;
    anchors[(y ~/ frame, x ~/ frame)] = (x % frame, y % frame);
    rgba.fillRange(i, i + 4, 0);
  }
  return anchors;
}
