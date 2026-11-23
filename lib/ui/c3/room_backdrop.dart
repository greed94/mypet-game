import 'dart:ui';

/// 폴라로이드 안에 쓰는 집의 벽과 마루, 연보라 방석.
void paintRoomBackdrop(
  Canvas canvas,
  Size size, {
  required double floorY,
  required Rect rug,
}) {
  final w = size.width, h = size.height;
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7E5D6));
  final seam = Paint()..color = const Color(0xFFF2DCCA);
  for (var x = 22.0; x < w; x += 24) {
    canvas.drawRect(Rect.fromLTWH(x, 0, 2, h), seam);
  }
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, 8),
    Paint()..color = const Color(0xFFEDD2BD),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, floorY, w, h - floorY),
    Paint()..color = const Color(0xFFEED5B7),
  );
  final plank = Paint()..color = const Color(0xFFE3C4A2);
  for (var y = floorY + 22; y < h; y += 24) {
    canvas.drawRect(Rect.fromLTWH(0, y, w, 2), plank);
  }
  canvas.drawRect(
    Rect.fromLTWH(0, floorY - 12, w, 12),
    Paint()..color = const Color(0xFFE4C6AB),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, floorY - 12, w, 3),
    Paint()..color = const Color(0xFFD6B393),
  );
  canvas.drawOval(rug, Paint()..color = const Color(0xFFC9BCEC));
  canvas.drawOval(rug.deflate(5), Paint()..color = const Color(0xFFE4DCF8));
  canvas.drawOval(rug.deflate(12), Paint()..color = const Color(0xFFD6CBF3));
}
