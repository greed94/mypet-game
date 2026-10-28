import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/pet_rules.dart';

const base = PetStats(mood: 65, hunger: 30, energy: 80, affection: 10);
final afternoon = DateTime(2026, 9, 25, 14);

void main() {
  test('친밀도는 세 단계로 나뉘고 가족은 2시간만 비워도 크게 반긴다', () {
    expect(intimacyOf(10), Intimacy.stranger);
    expect(intimacyOf(50), Intimacy.friend);
    expect(intimacyOf(80), Intimacy.family);
    expect(greetAfterFor(Intimacy.family), const Duration(hours: 2));
    expect(greetAfterFor(Intimacy.stranger), const Duration(hours: 6));
    expect(
      onReturn(
        base,
        const Duration(hours: 3),
        afternoon,
        threshold: greetAfterFor(Intimacy.family),
      ).greeting,
      Greeting.big,
    );
    expect(
      onReturn(
        base,
        const Duration(hours: 5),
        afternoon,
        threshold: greetAfterFor(Intimacy.stranger),
      ).greeting,
      Greeting.hello,
    );
  });

  test('아기는 2주 이상 지나고 돌봄 점수가 차야 어른이 된다', () {
    final born = afternoon.subtract(const Duration(days: 15));
    expect(shouldGrow(PetStage.puppy, born, 60, afternoon), isTrue);
    expect(shouldGrow(PetStage.puppy, born, 30, afternoon), isFalse);
    expect(
      shouldGrow(
        PetStage.puppy,
        afternoon.subtract(const Duration(days: 3)),
        100,
        afternoon,
      ),
      isFalse,
    );
    expect(shouldGrow(PetStage.adult, born, 100, afternoon), isFalse);
  });

  test('비 오는 날은 창가에 앉으러 가고, 더운 날은 늘어져 있다', () {
    var window = 0, lazy = 0;
    for (var seed = 0; seed < 60; seed++) {
      if (chooseNext(
            base,
            afternoon,
            Random(seed),
            weather: WeatherMood.watchWindow,
          ).behavior ==
          Behavior.watchWindow) {
        window++;
      }
      if (chooseNext(
            base,
            afternoon,
            Random(seed),
            weather: WeatherMood.lazy,
          ).behavior ==
          Behavior.lieBeside) {
        lazy++;
      }
    }
    expect(window, greaterThan(15));
    expect(lazy, greaterThan(15));
    expect(
      chooseNext(
            base,
            afternoon,
            Random(1),
            weather: WeatherMood.watchWindow,
          ).targetX ??
          windowX,
      windowX,
    );
  });

  test('낯가리는 동안은 가운데까지 안 오고, 가족은 제 발로 앞에 온다', () {
    for (var seed = 0; seed < 60; seed++) {
      final step = chooseNext(
        base,
        afternoon,
        Random(seed),
        intimacy: Intimacy.stranger,
      );
      if (step.behavior == Behavior.walk) {
        expect(step.targetX, lessThanOrEqualTo(0.65));
      }
      expect(step.behavior, isNot(Behavior.run));
    }
    final runs = List.generate(
      60,
      (s) => chooseNext(base, afternoon, Random(s), intimacy: Intimacy.family),
    ).where((p) => p.behavior == Behavior.run).length;
    expect(runs, greaterThan(2));
  });

  test('산책 뒤에는 기분이 오르고 조금 지치며, 걸음이 많을수록 돌봄 점수가 크다', () {
    final short = afterWalk(base, 500, const Duration(minutes: 10));
    final long = afterWalk(base, 4000, const Duration(minutes: 60));
    expect(short.stats.mood, greaterThan(base.mood));
    expect(short.stats.energy, lessThan(base.energy));
    expect(long.care, greaterThan(short.care));
    expect(long.stats.energy, greaterThanOrEqualTo(base.energy - 25));
  });
}
