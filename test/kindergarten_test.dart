import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/kindergarten.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

void main() {
  const start = PetStats(mood: 50, hunger: 40, energy: 90, affection: 30);

  test('아침 7시부터 저녁 7시까지 열고, 맡기는 건 오후 5시 전까지다', () {
    expect(kinderOpen(at(6, 59)), isFalse);
    expect(kinderOpen(at(7)), isTrue);
    expect(kinderOpen(at(18, 59)), isTrue);
    expect(kinderOpen(at(19)), isFalse);
    expect(canDropOff(at(16, 59)), isTrue);
    expect(canDropOff(at(17)), isFalse);
    expect(pickupAt(at(9, 30)), at(19));
  });

  test('맡긴 상태는 저녁 7시에 끝나고, 시계를 맡긴 때보다 앞으로 돌리면 바로 끝난다', () {
    final dropped = at(9);
    expect(inDaycareAt(dropped, at(9)), isTrue);
    expect(inDaycareAt(dropped, at(18, 59)), isTrue);
    expect(inDaycareAt(dropped, at(19)), isFalse);
    expect(inDaycareAt(dropped, at(8, 59)), isFalse);
    expect(
      inDaycareAt(dropped, dropped.subtract(const Duration(days: 3))),
      isFalse,
    );
  });

  test('유치원에선 점심을 먹고, 낮잠을 자고, 친구들과 놀아 기분이 오른다', () {
    final morning = applyDaycare(start, at(9), at(11, 50));
    expect(morning.hunger, greaterThan(start.hunger));
    expect(morning.mood, greaterThan(start.mood));
    expect(morning.energy, lessThan(start.energy));

    final lunch = applyDaycare(start, at(9), at(12, 10));
    expect(lunch.hunger, lessThanOrEqualTo(16));

    final beforeNap = applyDaycare(start, at(9), at(13));
    final afterNap = applyDaycare(start, at(9), at(14));
    expect(afterNap.energy, greaterThan(beforeNap.energy));

    final day = applyDaycare(start, at(9), at(19));
    expect(day.mood, lessThanOrEqualTo(85));
    expect(day.mood, greaterThan(80));
    expect(day.energy, greaterThanOrEqualTo(5));
    // 집에 혼자 있던 날보다 덜 배고프다.
    expect(day.hunger, lessThan(applyElapsed(start, at(9), at(19)).hunger));
  });

  test('비운 사이를 유치원 몫과 집 몫으로 나눈다', () {
    final split = elapsedWithDaycare(start, at(9), at(21), dropped: at(9));
    final byHand = applyElapsed(
      applyDaycare(start, at(9), at(19)),
      at(19),
      at(21),
    );
    expect(split.hunger, closeTo(byHand.hunger, 1e-9));
    expect(split.mood, closeTo(byHand.mood, 1e-9));
    expect(split.energy, closeTo(byHand.energy, 1e-9));

    final plain = elapsedWithDaycare(start, at(9), at(21));
    expect(plain.hunger, applyElapsed(start, at(9), at(21)).hunger);

    // 하원 뒤에 시작한 구간은 집 규칙만.
    final late = elapsedWithDaycare(start, at(20), at(22), dropped: at(9));
    expect(late.hunger, applyElapsed(start, at(20), at(22)).hunger);

    // 시계가 되돌아가면 그대로.
    final back = elapsedWithDaycare(start, at(12), at(10), dropped: at(9));
    expect(back.hunger, start.hunger);
  });

  test('수업은 아직 못 배운 개인기 중 가장 많이 해낸 것을 고르고, 칩이 없는 건 빼고, 다 배웠으면 없다', () {
    expect(lessonTrick({}), Trick.sit);
    expect(
      lessonTrick({
        Trick.sit: const TrickProgress(attempts: 5, successes: 3),
        Trick.down: const TrickProgress(attempts: 3, successes: 2),
        Trick.spin: const TrickProgress(attempts: 2, successes: 1),
        Trick.name: const TrickProgress(attempts: 9, successes: 2),
      }),
      Trick.down,
    );
    expect(
      lessonTrick({
        for (final t in Trick.values)
          t: const TrickProgress(attempts: 3, successes: 3),
      }),
      isNull,
    );
  });

  test('유치원 친구는 아기 셋이고 같은 날엔 같은 얼굴이다', () {
    final a = friendsOn(at(9));
    expect(a.length, 3);
    expect(a.every((g) => g.puppy), isTrue);
    expect(friendsOn(at(17)).map((g) => g.id), a.map((g) => g.id));
    expect(a.map((g) => g.id).toSet().length, 3);
  });

  test('펫은 유치원에서 뛰고 놀다가 1시엔 잔다', () {
    final r = Random(4);
    final seen = <Behavior>{};
    for (var i = 0; i < 300; i++) {
      final s = kinderStep(r, at(10));
      seen.add(s.behavior);
      if (s.targetX case final t?) expect(t, inInclusiveRange(0.1, 0.9));
    }
    expect(seen, containsAll([Behavior.run, Behavior.walk, Behavior.happy]));
    expect(seen, isNot(contains(Behavior.sleep)));
    expect(kinderStep(r, at(13, 20)).behavior, Behavior.sleep);
  });

  test('유치원 친구는 제 자리 둘레를 돌아다니고, 낮잠 시간엔 돌아다니지 않는다', () {
    final mind = GuestMind(Random(7), seat: 0.5, roam: 0.14);
    final seen = <Behavior>{};
    for (var i = 0; i < 300; i++) {
      mind.next(night: false);
      seen.add(mind.step.behavior);
      if (mind.step.targetX case final t?) {
        expect(t, inInclusiveRange(0.36, 0.64));
      }
    }
    expect(seen, containsAll([Behavior.run, Behavior.walk, Behavior.happy]));
    for (var i = 0; i < 100; i++) {
      mind.next(night: true);
      expect(mind.step.targetX, isNull);
    }
  });
}
