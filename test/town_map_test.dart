import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/ui/town_map.dart';

void main() {
  testWidgets('이름표 아래쪽을 눌러도 그곳이 골라지고, 칸이 닿은 이웃이 가로채지 않는다', (tester) async {
    final picked = <Spot>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: TownMap(onPick: picked.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cafe = tester.getRect(find.text('카페'));
    // 글자 바로 아래, 이름표 바닥 근처: 겹친 '간식 가게' 칸이 가로채던 자리.
    await tester.tapAt(Offset(cafe.center.dx, cafe.bottom + 5));
    await tester.pump();
    expect(picked, [Spot.cafe]);

    for (final s in [Spot.hospital, Spot.treatShop, Spot.home, Spot.park]) {
      await tester.tapAt(tester.getCenter(find.text(s.label)));
    }
    await tester.pump();
    expect(picked, [
      Spot.cafe,
      Spot.hospital,
      Spot.treatShop,
      Spot.home,
      Spot.park,
    ]);
  });
}
