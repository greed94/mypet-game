import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_rules.dart';

void main() {
  test('손님은 제 쿠션에서 앉기·둘러보기·킁킁·졸기만 하고 걷지 않는다', () {
    final mind = GuestMind(Random(3), seat: 0.5);
    final seen = <Behavior>{};
    for (var i = 0; i < 300; i++) {
      mind.next(night: false);
      seen.add(mind.step.behavior);
      expect(mind.step.targetX, isNull);
    }
    expect(
      seen,
      containsAll([
        Behavior.sit,
        Behavior.sniff,
        Behavior.idle,
        Behavior.sleep,
      ]),
    );
    expect(
      seen.difference({
        Behavior.sit,
        Behavior.idle,
        Behavior.sniff,
        Behavior.sleep,
      }),
      isEmpty,
    );
  });

  test('밤엔 손님이 거의 잔다', () {
    final mind = GuestMind(Random(5), seat: 0.3);
    var asleep = 0;
    for (var i = 0; i < 200; i++) {
      mind.next(night: true);
      if (mind.step.behavior == Behavior.sleep) asleep++;
      expect(mind.step.behavior, isIn([Behavior.sleep, Behavior.idle]));
    }
    expect(asleep, greaterThan(150));
  });

  test('따라 하기 줄은 차례로 하고 끝나면 평소대로 돌아간다', () {
    final mind = GuestMind(Random(1), seat: 0.5);
    mind.act(const [PetStep(Behavior.idle, 0.7), PetStep(Behavior.sit, 2.4)]);
    expect(mind.step.behavior, Behavior.idle);
    mind.tick(0.8, night: false);
    expect(mind.step.behavior, Behavior.sit);
    expect(mind.step.seconds, 2.4);
    mind.tick(2.5, night: false);
    expect(mind.step.targetX, isNull);
  });

  test('시간이 흐르면 다음 동작으로 넘어간다', () {
    final mind = GuestMind(Random(1), seat: 0.5);
    final first = mind.step;
    mind.tick(first.seconds + 0.1, night: false);
    expect(identical(mind.step, first), isFalse);
  });

  test('같은 시간대(펫의 하루를 여섯 시간씩: 5·11·17·23시)엔 같은 손님 둘이나 셋이고 서로 다르다', () {
    final a = guestsAt(DateTime(2026, 10, 2, 11));
    final b = guestsAt(DateTime(2026, 10, 2, 16, 59));
    expect(a.map((g) => g.id), b.map((g) => g.id));
    expect(a.length, inInclusiveRange(2, 3));
    expect(a.map((g) => g.id).toSet().length, a.length);
  });

  test('날이 바뀌면 손님 조합도 바뀐다', () {
    final combos = {
      for (var d = 0; d < 14; d++)
        guestsAt(DateTime(2026, 10, 1 + d, 15)).map((g) => g.id).join(','),
    };
    expect(combos.length, greaterThan(3));
  });

  test('카페 밤은 21시부터 7시 전까지', () {
    expect(cafeNight(DateTime(2026, 10, 2, 20, 59)), isFalse);
    expect(cafeNight(DateTime(2026, 10, 2, 21)), isTrue);
    expect(cafeNight(DateTime(2026, 10, 3, 6, 59)), isTrue);
    expect(cafeNight(DateTime(2026, 10, 3, 7)), isFalse);
  });

  test('펫의 카페 동작은 걷기·앉기·킁킁·서기뿐이고 걷기 목적지는 바닥 안이다', () {
    final r = Random(2);
    final seen = <Behavior>{};
    for (var i = 0; i < 300; i++) {
      final s = cafeStep(r);
      seen.add(s.behavior);
      if (s.targetX case final t?) expect(t, inInclusiveRange(0.1, 0.9));
    }
    expect(seen, {Behavior.walk, Behavior.sit, Behavior.sniff, Behavior.idle});
  });

  test('쿠션 자리는 손님 수대로 왼쪽부터 벌어진다', () {
    for (final n in [1, 2, 3]) {
      final seats = seatsFor(n);
      expect(seats.length, n);
      expect(seats, [...seats]..sort());
      for (final s in seats) {
        expect(s, inInclusiveRange(0.15, 0.85));
      }
    }
  });

  test('단골은 모두 있는 모양 틀을 쓰고 id가 겹치지 않는다', () {
    expect(cafeRegulars.map((g) => g.id).toSet().length, cafeRegulars.length);
    for (final g in cafeRegulars) {
      expect(
        g.shape,
        isIn(['papillon', 'maltese', 'shiba', 'retriever', 'corgi', 'pug']),
      );
    }
  });
}
