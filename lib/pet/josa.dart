/// 받침에 따라 조사를 고른다. pair는 '을/를', '이/가', '은/는', '과/와'처럼 받침 있는 쪽을 앞에 쓴다.
String josa(String word, String pair) {
  final [withBatchim, without] = pair.split('/');
  if (word.isEmpty) return word + without;
  final code = word.runes.last;
  final hangul = code >= 0xAC00 && code <= 0xD7A3;
  return word + (hangul && (code - 0xAC00) % 28 != 0 ? withBatchim : without);
}
