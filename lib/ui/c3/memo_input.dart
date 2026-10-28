import 'package:flutter/material.dart';

import 'c3_theme.dart';
import 'pixel_icon.dart';
import 'tape.dart';

/// 줄 공책 메모지 입력칸. [onMic] 이 null 이면 마이크를 숨긴다.
class MemoInput extends StatelessWidget {
  const MemoInput({
    super.key,
    required this.controller,
    required this.hint,
    this.listening = false,
    this.onMic,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final bool listening;
  final VoidCallback? onMic;
  final ValueChanged<String>? onSubmit;

  static const _none = InputBorder.none;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: C3Colors.card,
            border: Border.all(color: C3Colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(98, 72, 50, .10),
                offset: Offset(0, 1),
                blurRadius: 0.9,
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: Color(0xFFF5BEC6)),
              ),
              const Positioned(
                left: 14,
                right: 50,
                top: 35,
                height: 1,
                child: ColoredBox(color: Color(0xFFEAD9C6)),
              ),
              Positioned.fill(
                left: 24,
                right: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: TextField(
                          controller: controller,
                          onSubmitted: onSubmit,
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          style: C3Text.body,
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: C3Text.body.copyWith(
                              color: C3Colors.hint,
                            ),
                            isCollapsed: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: _none,
                            enabledBorder: _none,
                            focusedBorder: _none,
                            disabledBorder: _none,
                            errorBorder: _none,
                            focusedErrorBorder: _none,
                          ),
                        ),
                      ),
                    ),
                    if (onMic != null) _mic(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 왼쪽 끝이 화면 가장자리로 올라가게 기울인다. 반대로 기울이면 위 행동 줄의 첫 글자를 덮는다.
        const Positioned(
          left: -20,
          top: -9,
          child: Tape(
            width: 56,
            height: 20,
            color: C3Colors.tapeYellow,
            angle: 24,
          ),
        ),
      ],
    );
  }

  Widget _mic() {
    return Semantics(
      button: true,
      label: listening ? '듣기 멈추기' : '음성으로 말 걸기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onMic,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening
                    ? const Color(0xFFF8CAD4)
                    : const Color(0x00F8CAD4),
                border: Border.all(
                  color: listening ? Colors.white : const Color(0x00FFFFFF),
                  width: 2,
                ),
              ),
              child: const PixelIcon('mic'),
            ),
          ),
        ),
      ),
    );
  }
}
