import 'package:flutter/widgets.dart';

import 'c3_theme.dart';
import 'tape.dart';

/// 폴라로이드 사진 틀. [child] 는 캡션을 뺀 남는 높이를 전부 쓴다.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    required this.caption,
    this.captionRight,
  });

  final Widget child;
  final String caption;
  final String? captionRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(3)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(98, 72, 50, .18),
                offset: Offset(0, 3),
                blurRadius: 5.2,
              ),
              BoxShadow(
                color: Color.fromRGBO(98, 72, 50, .12),
                offset: Offset(0, 1),
                blurRadius: 0.9,
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: child,
                ),
              ),
              SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: C3Fonts.gaegu,
                            fontFamilyFallback: C3Fonts.fallback,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -.8,
                            color: C3Colors.ink2,
                          ),
                        ),
                      ),
                      if (captionRight != null)
                        Text(
                          captionRight!,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: C3Fonts.jua,
                            fontFamilyFallback: C3Fonts.fallback,
                            fontSize: 13,
                            color: C3Colors.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: -8,
          top: -2,
          child: Tape(
            width: 76,
            height: 24,
            color: C3Colors.tapeMint,
            angle: -35,
          ),
        ),
        const Positioned(
          right: -8,
          top: -2,
          child: Tape(
            width: 76,
            height: 24,
            color: C3Colors.tapePink,
            angle: 35,
            pattern: TapePattern.dots,
          ),
        ),
      ],
    );
  }
}
