import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mypet/ui/c3/c3_theme.dart';

Future<void> loadPreviewFonts() async {
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
}
