import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/pet_rules.dart';

const base = PetStats(mood: 65, hunger: 30, energy: 80, affection: 50);
final evening = DateTime(2026, 10, 5, 20, 30);

void main() {
  test('늘 오는 때면 달려 나오지 않고, 기다렸다는 듯 가볍게 반긴다', () {
    final clingy = onReturn(
      base,
      const Duration(hours: 7),
      evening,
      usual: 1,
      traits: const Traits(activity: 0.5, attachment: 0.8),
    );
    expect(clingy.greeting, Greeting.usual);
    expect(clingy.steps.first.behavior, Behavior.waitAtDoor);
    expect(clingy.steps.map((s) => s.behavior), isNot(contains(Behavior.run)));
    final cool = onReturn(
      base,
      const Duration(hours: 7),
      evening,
      usual: 1,
      traits: const Traits(activity: 0.5, attachment: 0.2),
    );
    expect(cool.steps.first.behavior, Behavior.sit);
    // 평소와 다른 때 오면 크게 반긴다.
    final surprise = onReturn(base, const Duration(hours: 7), evening);
    expect(surprise.greeting, Greeting.big);
    expect(surprise.steps.map((s) => s.behavior), contains(Behavior.run));
  });

  test('잘 시간이 다가오면 느릿느릿 걸어와서 기댄다', () {
    final r = onReturn(
      base,
      const Duration(hours: 5),
      DateTime(2026, 10, 6, 0, 30),
      asleep: false,
      drowsy: true,
    );
    expect(r.steps.first.behavior, Behavior.walk);
    expect(r.steps.map((s) => s.behavior), isNot(contains(Behavior.run)));
  });

  test('밤에는 성격 따라 꼬리를 흔들거나 귀만 쫑긋하고 계속 잔다', () {
    final night = DateTime(2026, 10, 6, 2);
    final clingy = onReturn(
      base,
      const Duration(hours: 6),
      night,
      traits: const Traits(activity: 0.5, attachment: 0.9),
    );
    expect(clingy.steps.map((s) => s.behavior), contains(Behavior.happy));
    final aloof = onReturn(
      base,
      const Duration(hours: 6),
      night,
      traits: const Traits(activity: 0.5, attachment: 0.1),
    );
    expect(aloof.steps.single.behavior, Behavior.sleep);
    expect(aloof.greeting, Greeting.sleepy);
  });

  test('크게 반기는 모습이 여러 가지라 매번 같지 않다', () {
    final r = Random(3);
    final seen = <String>{
      for (var i = 0; i < 30; i++)
        onReturn(
          base,
          const Duration(hours: 7),
          evening,
          traits: const Traits(activity: 0.8, attachment: 0.5),
          random: r,
        ).steps.map((s) => s.behavior.name).join('>'),
    };
    expect(seen.length, greaterThanOrEqualTo(3));
  });

  test('성격은 펫마다 늘 같게 나오고, 극단적인 성격은 드물다', () {
    expect(Traits.seeded(42).activity, Traits.seeded(42).activity);
    final all = [for (var i = 0; i < 400; i++) Traits.seeded(i)];
    final extreme = all.where((t) => t.activity < 0.1 || t.activity > 0.9);
    expect(extreme.length, lessThan(20));
    expect(all.every((t) => t.attachment >= 0 && t.attachment <= 1), isTrue);
  });

  test('아기와 덜 활발한 애는 낮에도 자주 졸고, 활발한 애는 공놀이에 덜 지친다', () {
    int naps(bool puppy, double activity) {
      final r = Random(1);
      var n = 0;
      for (var i = 0; i < 2000; i++) {
        final step = chooseNext(
          base,
          evening,
          r,
          asleep: false,
          puppy: puppy,
          traits: Traits(activity: activity, attachment: 0.5),
        );
        if (step.behavior == Behavior.sleep) n++;
      }
      return n;
    }

    expect(naps(true, 0.2), greaterThan(naps(false, 0.8) * 3));
    final lazy = afterFetch(
      base,
      bond: false,
      traits: const Traits(activity: 0.1, attachment: 0.5),
    );
    final lively = afterFetch(
      base,
      bond: false,
      traits: const Traits(activity: 0.9, attachment: 0.5),
    );
    expect(lively.energy, greaterThan(lazy.energy));
  });
}
