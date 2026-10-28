/// 한글은 음절 사이에서도 줄이 바뀌어 '발/표회'처럼 낱말이 갈린다. 낱말 안의 글자 사이에
/// 줄바꿈을 막는 보이지 않는 글자(WORD JOINER, U+2060)를 넣어 띄어쓰기에서만 줄이 바뀌게 한다.
/// 웹 글의 word-break: keep-all과 같다. 한 줄보다 긴 낱말은 엔진이 그래도 자른다.
String keepWords(String s) {
  final out = StringBuffer();
  final chars = s.runes.toList();
  for (var i = 0; i < chars.length; i++) {
    out.writeCharCode(chars[i]);
    if (i + 1 < chars.length && !_space(chars[i]) && !_space(chars[i + 1])) {
      out.write('⁠');
    }
  }
  return out.toString();
}

bool _space(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x2060;
