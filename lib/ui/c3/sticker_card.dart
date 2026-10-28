import 'package:flutter/material.dart';

import 'c3_theme.dart';
import 'tape.dart';

/// 종이 위에 붙인 흰 카드. [tape] 색을 주면 위 가운데에 테이프를 붙인다.
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tape,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tape;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: padding,
          decoration: const BoxDecoration(
            color: C3Colors.card,
            borderRadius: BorderRadius.all(Radius.circular(6)),
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
          child: child,
        ),
        if (tape != null)
          Positioned(
            top: -11,
            left: 0,
            right: 0,
            child: Center(
              child: Tape(width: 74, height: 22, color: tape!, angle: -4),
            ),
          ),
      ],
    );
  }
}

/// 흰 카드 다이얼로그. [actions] 가 없으면 스탬프색 '확인' 버튼 하나.
Future<T?> showC3Dialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: StickerCard(
        tape: C3Colors.tapeYellow,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: C3Fonts.jua,
                fontFamilyFallback: C3Fonts.fallback,
                fontSize: 22,
                height: 1.2,
                color: C3Colors.ink,
              ),
            ),
            const SizedBox(height: 10),
            // 긴 글에 사진까지 붙으면 작은 화면에서 넘쳤다. 버튼은 남기고 본문만 스크롤.
            Flexible(
              child: SingleChildScrollView(
                child: DefaultTextStyle.merge(style: C3Text.body, child: body),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children:
                  actions ??
                  [
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('확인'),
                    ),
                  ],
            ),
          ],
        ),
      ),
    ),
  );
}
