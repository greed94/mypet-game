import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/cuddle.dart';
import 'package:mypet/pet/pet_rules.dart';

void main() {
  test('손 베개: 사이마다 다르게 다가오고, 손에 닿은 단계가 하나씩 있다', () {
    for (final i in Intimacy.values) {
      for (final x in [0.05, 0.3, 0.5, 0.95]) {
        final steps = handSteps(i, x);
        expect(steps.where((s) => s.tag == StepTag.hand), hasLength(1));
        expect(steps.first.seconds, greaterThanOrEqualTo(8));
        for (final s in steps) {
          if (s.targetX case final t?) expect(t, inInclusiveRange(0.1, 0.9));
          expect((s.thought ?? '').length, lessThanOrEqualTo(40));
        }
      }
    }
    // 낯가릴 땐 손에서 떨어져 냄새만 맡는다.
    final shy = handSteps(Intimacy.stranger, 0.5);
    expect((shy.first.targetX! - 0.5).abs(), closeTo(0.16, 1e-9));
    expect(shy.map((s) => s.behavior), isNot(contains(Behavior.lieBeside)));
    // 가족이면 손을 베고 눕고, 졸리면 그대로 잔다.
    final family = handSteps(Intimacy.family, 0.4);
    expect(family.first.targetX, 0.4);
    expect(family.last.behavior, Behavior.lieBeside);
    expect(
      handSteps(Intimacy.family, 0.4, sleepy: true).last.behavior,
      Behavior.sleep,
    );
  });

  test('조르기는 가운데로 와서 조르고, 조르는 단계에 beg 꼬리표가 있다', () {
    final steps = begSteps(Random(1));
    expect(steps.first.targetX, 0.5);
    expect(steps.where((s) => s.tag == StepTag.beg), hasLength(1));
    for (var seed = 0; seed < 20; seed++) {
      for (final s in begSteps(Random(seed))) {
        expect((s.thought ?? '').length, lessThanOrEqualTo(40));
      }
    }
    expect(begAnsweredSteps.first.behavior, Behavior.jump);
  });
}
