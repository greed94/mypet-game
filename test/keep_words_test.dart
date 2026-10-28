import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/ui/keep_words.dart';

/// 폭 [width]에 [text]를 놓았을 때 줄마다의 글자(보이지 않는 글자는 뺀다).
List<String> _lines(String text, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 10, fontFamily: 'FlutterTest'),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final lines = <String>[];
  var start = 0;
  for (final m in painter.computeLineMetrics()) {
    final end = painter
        .getLineBoundary(
          painter.getPositionForOffset(
            Offset(width, m.baseline - m.ascent + m.height / 2),
          ),
        )
        .end;
    lines.add(text.substring(start, end).replaceAll('⁠', '').trim());
    start = end;
  }
  painter.dispose();
  return lines;
}

void main() {
  test('낱말 사이에만 보이지 않는 글자를 넣는다', () {
    expect(keepWords('발표회 날'), '발⁠표⁠회 날');
    expect(keepWords(''), '');
    expect(keepWords('a'), 'a');
    // 두 번 거쳐도 같다.
    expect(keepWords(keepWords('도장 받았다!')), keepWords('도장 받았다!'));
  });

  test('줄은 띄어쓰기에서만 바뀌어 낱말이 갈리지 않는다', () {
    const text = '오늘은 금요일 발표회 날';
    // 한 줄에 열 글자쯤(10px 글꼴, 폭 105px). '오늘은 금요일 발표'까지 들어간다.
    final plain = _lines(text, 105);
    final kept = _lines(keepWords(text), 105);
    // 그냥 두면 '발표회'가 줄 끝에서 갈린다.
    expect(plain, ['오늘은 금요일 발표', '회 날']);
    expect(kept, ['오늘은 금요일', '발표회 날']);
  });
}
