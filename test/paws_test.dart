import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/paws.dart';
import 'package:mypet/pet/shapes.dart';

void main() {
  test('산책은 5분에 하나, 여섯까지', () {
    expect(walkPaws(const Duration(minutes: 4)), 0);
    expect(walkPaws(const Duration(minutes: 5)), 1);
    expect(walkPaws(const Duration(minutes: 22)), 4);
    expect(walkPaws(const Duration(hours: 2)), 6);
    expect(walkPaws(const Duration(minutes: -3)), 0);
  });

  test('하루 몫을 넘기지 않는다', () {
    expect(cappedPaws(3, earnedToday: 0), 3);
    expect(cappedPaws(3, earnedToday: 9), 1);
    expect(cappedPaws(3, earnedToday: pawsDailyCap), 0);
    expect(cappedPaws(3, earnedToday: pawsDailyCap + 4), 0);
  });

  test('이정표는 쉼표로 저장했다 되읽힌다', () {
    final marks = {'trick:sit', 'days:7', 'bestie:coco'};
    expect(parseMarks(marksToCsv(marks)), marks);
    expect(parseMarks(null), isEmpty);
    expect(parseMarks(''), isEmpty);
  });

  test('꾸미기: id가 겹치지 않고, 처음 것은 무료이고, 기본 목걸이 색과 같다', () {
    expect(cosmetics.map((c) => c.id).toSet().length, cosmetics.length);
    expect(freeCosmetics, {'collar_red', 'rug_lavender'});
    expect(cosmetics.first.colors.single, defaultAccent);
    for (final c in cosmetics) {
      expect(c.colors.length, c.kind == CosmeticKind.rug ? 3 : 1);
      expect(c.label.length, lessThanOrEqualTo(8));
    }
    expect(collarFor(0xFF4FA3D1).id, 'collar_sky');
    expect(collarFor(0x12345678).id, 'collar_red');
    expect(cosmeticById('rug_mint')?.price, 12);
    expect(cosmeticById('nope'), isNull);
  });
}
