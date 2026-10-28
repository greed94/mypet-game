import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/josa.dart';

void main() {
  test('받침이 있으면 앞 조사, 없으면 뒤 조사', () {
    expect(josa('도토리', '을/를'), '도토리를');
    expect(josa('솔방울', '을/를'), '솔방울을');
    expect(josa('콩이', '이/가'), '콩이가');
    expect(josa('밤', '이/가'), '밤이');
  });
}
