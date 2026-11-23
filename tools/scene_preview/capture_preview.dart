import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 위젯이 그린 프레임을 그대로 저장한다. 각 캡처의 네이티브 이미지는 바로 해제한다.
Future<void> capturePreview(
  WidgetTester tester,
  Finder surface,
  File output, {
  double pixelRatio = 1.5,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(surface);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await output.writeAsBytes(png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
