import 'dart:async';
import 'dart:ui' as ui;

import 'palette.dart';

const spriteFrame = 32;

/// 프레임의 입 위치(프레임 안 좌표). 키는 (줄, 칸)이고, 표시가 없는 프레임은 그 줄 첫 칸 값을 쓴다.
(int, int) mouthAt(Map<(int, int), (int, int)> mouths, int row, int col) =>
    mouths[(row, col)] ?? mouths[(row, 0)] ?? (28, 13);

/// 키 색으로 그린 강아지 시트를 펫 털색으로 칠한다. 입 위치 표시는 읽어 두고 지운다.
/// 방 안 강아지와 모양 고르기 미리보기가 같은 길을 써야, 고른 모습 그대로 방에 나온다.
Future<(ui.Image, Map<(int, int), (int, int)>)> paintSheet(
  ui.Image sheet, {
  required int main,
  required int second,
  required int accent,
  required int marking,
}) async {
  final data = await sheet.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final raw = data!.buffer.asUint8List();
  final mouths = takeMouthAnchors(raw, sheet.width, spriteFrame);
  final pixels = swapPalette(
    raw,
    main: main,
    second: second,
    accent: accent,
    marking: marking,
  );
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    sheet.width,
    sheet.height,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return (await done.future, mouths);
}
