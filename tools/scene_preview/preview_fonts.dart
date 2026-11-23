import 'package:flutter/services.dart';
import 'package:mypet/ui/c3/c3_theme.dart';

Future<void> loadPreviewFonts() async {
  const families = {
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    C3Fonts.jua: ['assets/fonts/Jua-Regular.ttf'],
    C3Fonts.gowun: ['assets/fonts/GowunDodum-Regular.ttf'],
    C3Fonts.gaegu: [
      'assets/fonts/Gaegu-Regular.ttf',
      'assets/fonts/Gaegu-Bold.ttf',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }
}
