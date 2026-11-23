import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const base = PetStats(mood: 65, hunger: 30, energy: 80, affection: 10);
final afternoon = DateTime(2026, 9, 25, 14);

void main() {
  test('23시간·25시간인 날도 현지 05시에 일기 날짜가 바뀐다', () {
    tzdata.initializeTimeZones();
    final coast = tz.getLocation('America/Los_Angeles');
    for (final (month, day, hours) in [(3, 8, 23), (11, 1, 25)]) {
      final before = tz.TZDateTime(coast, 2026, month, day, 4, 59);
      final after = tz.TZDateTime(coast, 2026, month, day, 5, 30);
      expect(dayKey(petDate(before)), dayKey(DateTime(2026, month, day - 1)));
      expect(dayKey(petDate(after)), dayKey(DateTime(2026, month, day)));
      expect(daysTogether(before, after), 2);
      expect(daysTogether(after, before), 1);
      final date = petDate(before);
      tz.TZDateTime inCoast(DateTime d) =>
          tz.TZDateTime(coast, d.year, d.month, d.day, d.hour);
      final start = inCoast(petDayStart(date));
      final end = inCoast(petDayStart(date, offsetDays: 1));
      expect(end.difference(start).inHours, hours);
      expect(end.isAfter(before), isTrue);
      expect(
        inCoast(petDayStart(petDate(after), offsetDays: 1)).isAfter(after),
        isTrue,
      );
    }
  });

  group('applyElapsed', () {
    test('낮 6시간 비우면 배고파지고 기운이 줄어든다', () {
      final s = applyElapsed(
        base,
        afternoon.subtract(const Duration(hours: 6)),
        afternoon,
      );
      expect(s.hunger, closeTo(60, 0.01));
      expect(s.energy, closeTo(62, 0.01));
      expect(s.affection, 10);
    });

    test('밤에는 자면서 기운이 찬다', () {
      final from = DateTime(2026, 9, 25, 23);
      final s = applyElapsed(
        base.copyWith(energy: 20),
        from,
        from.add(const Duration(hours: 5)),
      );
      expect(s.energy, closeTo(80, 0.01));
    });

    test('많이 배고프면 기분이 기준선 35까지 내려간다', () {
      final s = applyElapsed(
        base.copyWith(hunger: 90),
        afternoon.subtract(const Duration(hours: 10)),
        afternoon,
      );
      expect(s.mood, closeTo(35, 0.01));
    });

    test('시계가 뒤로 가면 아무것도 바꾸지 않는다', () {
      final s = applyElapsed(
        base,
        afternoon,
        afternoon.subtract(const Duration(hours: 1)),
      );
      expect(s.hunger, base.hunger);
    });

    test('오래 비워도 값은 0~100을 벗어나지 않는다', () {
      final s = applyElapsed(
        base,
        afternoon.subtract(const Duration(days: 60)),
        afternoon,
      );
      expect(s.hunger, 100);
      expect(s.energy, inInclusiveRange(0, 100));
      expect(s.mood, inInclusiveRange(0, 100));
    });
  });

  group('onReturn', () {
    test('낮에 4시간 이상 비우면 문 앞에서 기다리다 달려와 반긴다', () {
      final r = onReturn(base, const Duration(hours: 6), afternoon);
      expect(r.steps.map((s) => s.behavior), [
        Behavior.waitAtDoor,
        Behavior.run,
        Behavior.happy,
      ]);
      expect(r.steps.first.targetX, doorX);
      expect(r.stats.mood, 70);
    });

    test('30분~기준 시간이면 가볍게 반기고, 30분이 안 되면 모른 척한다', () {
      final hello = onReturn(base, const Duration(hours: 2), afternoon);
      expect(hello.greeting, Greeting.hello);
      expect(hello.steps.map((s) => s.behavior), [
        Behavior.sit,
        Behavior.happy,
      ]);
      final quick = onReturn(base, const Duration(minutes: 20), afternoon);
      expect(quick.greeting, Greeting.none);
      expect(quick.steps, isEmpty);
    });

    test('크게 반길 때는 달려오며 짖고, 밤에는 짖지 않는다', () {
      final big = onReturn(base, const Duration(hours: 6), afternoon);
      expect(big.steps.map((s) => s.cue), contains(Cue.bark));
      final night = onReturn(
        base,
        const Duration(hours: 8),
        DateTime(2026, 9, 25, 2),
      );
      expect(night.greeting, Greeting.sleepy);
      expect(night.steps.map((s) => s.cue), isNot(contains(Cue.bark)));
    });

    test('밤에는 뛰어나오지 않고 졸린 눈으로 잠깐 반긴 뒤 다시 잔다', () {
      final steps = onReturn(
        base,
        const Duration(hours: 8),
        DateTime(2026, 9, 25, 2),
      ).steps;
      expect(steps.map((s) => s.behavior), [Behavior.sit, Behavior.sleep]);
    });

    test('12시간 넘게 비워야 빙글빙글 돈다. 성격·모습이 달라도 6시간엔 달려와 반기기만 한다', () {
      final r = Random(5);
      for (final activity in [0.1, 0.5, 0.9]) {
        final traits = Traits(activity: activity, attachment: 0.5);
        for (var i = 0; i < 20; i++) {
          final six = onReturn(
            base,
            const Duration(hours: 6),
            afternoon,
            traits: traits,
            random: r,
          ).steps.map((s) => s.behavior);
          expect(six, isNot(contains(Behavior.spin)));
          expect(six, contains(Behavior.run));
          expect(six.last, Behavior.happy);
          final long = onReturn(
            base,
            const Duration(hours: 13),
            afternoon,
            traits: traits,
            random: r,
          ).steps.map((s) => s.behavior);
          expect(long, contains(Behavior.spin));
        }
      }
    });
  });

  group('chooseNext', () {
    test('밤이거나 기운이 없으면 잔다', () {
      expect(
        chooseNext(base, DateTime(2026, 9, 25, 1), Random(1)).behavior,
        Behavior.sleep,
      );
      expect(
        chooseNext(base.copyWith(energy: 10), afternoon, Random(1)).behavior,
        Behavior.sleep,
      );
    });

    test('배고프면 삐지거나 가만히 있고 돌아다니지 않는다', () {
      final hungry = base.copyWith(hunger: 90);
      for (var seed = 0; seed < 50; seed++) {
        expect(
          chooseNext(hungry, afternoon, Random(seed)).behavior,
          isIn([Behavior.sulk, Behavior.idle]),
        );
      }
    });

    test('걷기 목적지는 방 안이다', () {
      for (var seed = 0; seed < 50; seed++) {
        final step = chooseNext(base, afternoon, Random(seed));
        if (step.behavior == Behavior.walk) {
          expect(step.targetX, inInclusiveRange(0.2, 0.85));
        }
      }
    });
  });

  group('react', () {
    test('쓰다듬으면 기분과 친밀도가 오르고, 연타는 효과가 없다', () {
      final first = react(
        base,
        Interaction.pet,
        sleeping: false,
        cooledDown: true,
      );
      expect(first.step.behavior, Behavior.happy);
      expect(first.stats.mood, 71);
      expect(first.stats.affection, 12);
      final spam = react(
        base,
        Interaction.pet,
        sleeping: false,
        cooledDown: false,
      );
      expect(spam.step.behavior, Behavior.happy);
      expect(spam.stats.mood, base.mood);
    });

    test('친밀도는 간격을 두고만 오른다', () {
      final r = react(
        base,
        Interaction.pet,
        sleeping: false,
        cooledDown: true,
        bond: false,
      );
      expect(r.stats.mood, 71);
      expect(r.stats.affection, base.affection);
    });

    test('자는 중에 쓰다듬으면 잠깐 깨기만 한다', () {
      final r = react(base, Interaction.pet, sleeping: true, cooledDown: true);
      expect(r.step.behavior, Behavior.sit);
      expect(r.stats.affection, base.affection);
    });

    test('밥을 주면 배고픔이 줄고, 배부르면 안 먹는다', () {
      final fed = react(
        base,
        Interaction.feed,
        sleeping: false,
        cooledDown: true,
      );
      expect(fed.step.behavior, Behavior.eat);
      expect(fed.stats.hunger, 0);
      final full = react(
        base.copyWith(hunger: 5),
        Interaction.feed,
        sleeping: false,
        cooledDown: true,
      );
      expect(full.step.behavior, Behavior.sit);
      expect(full.stats.hunger, 5);
    });

    test('공을 물어 오면 기분이 오르고 조금 지친다', () {
      final s = afterFetch(base, bond: true);
      expect(s.mood, greaterThan(base.mood));
      expect(s.energy, lessThan(base.energy));
      expect(s.affection, base.affection + 1);
      expect(afterFetch(base, bond: false).affection, base.affection);
    });
  });
}
