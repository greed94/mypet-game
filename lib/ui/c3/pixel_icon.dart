import 'package:flutter/widgets.dart';

/// `assets/ui/<name>.png` (12×12) 를 정수배로 또렷하게 그린다.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.name, {super.key, this.scale = 2});

  final String name;
  final int scale;

  @override
  Widget build(BuildContext context) {
    final size = 12.0 * scale;
    return Image.asset(
      'assets/ui/$name.png',
      width: size,
      height: size,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
    );
  }
}
