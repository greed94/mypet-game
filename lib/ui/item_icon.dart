import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../pet/treasure.dart';
import 'c3/c3_theme.dart';

/// 발견물 그림. 방 크기로 그린 16×16 칸에서 그림 부분만 잘라 정수배로 키운다.
class ItemIcon extends StatelessWidget {
  const ItemIcon(
    this.item, {
    super.key,
    this.box = 56,
    this.silhouette = false,
  });

  final Item item;
  final double box;

  /// 아직 못 찾은 칸. 모양만 흐리게 보여 준다.
  final bool silhouette;

  /// 위젯 테스트는 테스트마다 시계(zone)가 따로라, 앞 테스트에서 시작한 시트 읽기가 끝나지 않은 채 남는다.
  @visibleForTesting
  static void resetCache() => _Sheet._loading = null;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Sheet>(
      future: _Sheet.load(),
      builder: (context, snap) => SizedBox.square(
        dimension: box,
        child: snap.data == null
            ? null
            : CustomPaint(
                painter: _ItemPainter(snap.data!, itemIndex(item), silhouette),
              ),
      ),
    );
  }
}

class _Sheet {
  _Sheet(this.image, this.bounds);

  final ui.Image image;
  final List<Rect> bounds;

  static Future<_Sheet>? _loading;
  static Future<_Sheet> load() => _loading ??= _read();

  static Future<_Sheet> _read() async {
    final data = await rootBundle.load('assets/items/items.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    const cell = 16;
    final cols = image.width ~/ cell;
    final bounds = <Rect>[];
    for (var i = 0; i < items.length; i++) {
      final ox = (i % cols) * cell, oy = (i ~/ cols) * cell;
      var l = cell, t = cell, r = -1, b = -1;
      for (var y = 0; y < cell; y++) {
        for (var x = 0; x < cell; x++) {
          final a = rgba.getUint8(((oy + y) * image.width + ox + x) * 4 + 3);
          if (a == 0) continue;
          if (x < l) l = x;
          if (y < t) t = y;
          if (x > r) r = x;
          if (y > b) b = y;
        }
      }
      bounds.add(
        r < 0
            ? Rect.fromLTWH(ox.toDouble(), oy.toDouble(), 16, 16)
            : Rect.fromLTRB(
                (ox + l).toDouble(),
                (oy + t).toDouble(),
                (ox + r + 1).toDouble(),
                (oy + b + 1).toDouble(),
              ),
      );
    }
    return _Sheet(image, bounds);
  }
}

class _ItemPainter extends CustomPainter {
  _ItemPainter(this.sheet, this.index, this.silhouette);

  final _Sheet sheet;
  final int index;
  final bool silhouette;

  @override
  void paint(Canvas canvas, Size size) {
    final src = sheet.bounds[index];
    final k = (size.shortestSide / src.longestSide).floorToDouble().clamp(
      1.0,
      12.0,
    );
    final w = src.width * k, h = src.height * k;
    final dst = Rect.fromLTWH(
      ((size.width - w) / 2).roundToDouble(),
      ((size.height - h) / 2).roundToDouble(),
      w,
      h,
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (silhouette) {
      paint.colorFilter = ColorFilter.mode(
        C3Colors.ink.withValues(alpha: 0.18),
        BlendMode.srcIn,
      );
    }
    canvas.drawImageRect(sheet.image, src, dst, paint);
  }

  @override
  bool shouldRepaint(_ItemPainter old) =>
      old.index != index || old.silhouette != silhouette;
}
