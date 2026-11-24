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
    this.captionContent,
    this.pictureHeight,
    this.controls,
    this.action,
  });

  final Widget child;
  final String caption;
  final String? captionRight;
  final Widget? captionContent;

  /// 지정하면 사진 영역의 높이를 유지하고 아래 캡션이 내용만큼 자란다.
  final double? pictureHeight;
  final Widget? controls;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: child,
    );
    final fixedCaptionHeight =
        captionContent != null || (controls == null && action != null)
        ? 48.0
        : 32.0;
    return Stack(
      fit: pictureHeight == null ? StackFit.expand : StackFit.passthrough,
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
            mainAxisSize: pictureHeight == null
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (pictureHeight == null)
                Expanded(child: picture)
              else
                SizedBox(
                  width: double.infinity,
                  height: pictureHeight,
                  child: picture,
                ),
              SizedBox(
                height: pictureHeight == null ? fixedCaptionHeight : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 1),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            captionContent ??
                            Text(
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
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: action == null ? double.infinity : 92,
                          ),
                          child: Text(
                            captionRight!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: C3Fonts.jua,
                              fontFamilyFallback: C3Fonts.fallback,
                              fontSize: 13,
                              color: C3Colors.ink3,
                            ),
                          ),
                        ),
                      if (action != null && controls == null) ...[
                        const SizedBox(width: 6),
                        action!,
                      ],
                    ],
                  ),
                ),
              ),
              if (controls != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: controls!,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 6),
                        action!,
                      ],
                    ],
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
