import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/spots.dart';

void main() {
  test('지도 이름표는 그림 안쪽이고 서로 겹치지 않는다', () {
    for (final s in Spot.values) {
      expect(s.x, inInclusiveRange(0.14, 0.86), reason: s.name);
      expect(s.y, inInclusiveRange(0.1, 0.94), reason: s.name);
      expect(s.label, isNotEmpty);
    }
    for (final a in Spot.values) {
      for (final b in Spot.values) {
        if (a.index >= b.index) continue;
        final dx = (a.x - b.x).abs(), dy = (a.y - b.y).abs();
        expect(dx > 0.26 || dy > 0.12, isTrue, reason: '${a.name}-${b.name}');
      }
    }
  });

  test('누르는 칸이 서로 겹치지 않는다', () {
    for (final a in Spot.values) {
      for (final b in Spot.values) {
        if (a.index >= b.index) continue;
        final dx = (a.x - b.x).abs(), dy = (a.y - b.y).abs();
        expect(
          dx >= spotTapWidth || dy >= spotTapHeight,
          isTrue,
          reason: '${a.name}-${b.name}',
        );
      }
    }
  });
}
