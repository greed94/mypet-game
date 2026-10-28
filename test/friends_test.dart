import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

void main() {
  test('만난 날마다 한 칸, 같은 날엔 그대로, 단짝에서 멈춘다', () {
    var f = const Friendship();
    expect(f.bond, Bond.none);
    f = f.met('2026-10-05');
    expect(f.bond, Bond.stranger);
    expect(f.days, 1);
    expect(identical(f.met('2026-10-05'), f), isTrue);
    f = f.met('2026-10-06').met('2026-10-07').met('2026-10-08');
    expect(f.bond, Bond.bestie);
    expect(f.days, 4);
    f = f.met('2026-10-09');
    expect(f.bond, Bond.bestie);
    expect(f.days, 5);
    expect(f.named('코코').name, '코코');
    expect(f.named('코코').bond, Bond.bestie);
  });

  test('이름이 없으면 생김새로 부르고, 이름은 다듬어 열 자까지', () {
    final g = cafeRegulars.first;
    expect(friendName(g, null), g.look);
    expect(friendName(g, const Friendship(name: '코코')), '코코');
    expect(cleanFriendName('  '), isNull);
    expect(cleanFriendName(' 코  코 '), '코 코');
    expect(cleanFriendName('가나다라마바사아자차카타'), '가나다라마바사아자차');
    // 이모지(두 단위짜리 글자) 한가운데가 잘리지 않는다.
    final emoji = cleanFriendName('가🐶🐶🐶🐶🐶🐶🐶🐶🐶🐶')!;
    expect(emoji.runes.length, 10);
    expect(emoji.endsWith('🐶'), isTrue);
  });

  test('사이마다 장면이 다르고 속마음은 40자 안쪽이다', () {
    for (final b in Bond.values) {
      final steps = meetSteps(b, 0.18, '꼬리 말린 갈색 애');
      expect(steps, isNotEmpty);
      for (final s in steps) {
        expect((s.thought ?? '').length, lessThanOrEqualTo(40));
        if (s.targetX case final x?) expect(x, inInclusiveRange(0.1, 0.9));
      }
    }
    expect(meetSteps(Bond.stranger, 0.18, 'x').first.targetX, 0.7);
    // 입구에서 오른쪽 끝까지 9초쯤 걸리니 걷기는 그보다 길어야 한다(닿으면 끝난다).
    for (final b in Bond.values) {
      final walk = meetSteps(b, 0.18, 'x').first;
      expect(walk.seconds, greaterThanOrEqualTo(8));
    }
    expect(meetSteps(Bond.sniff, 0.18, 'x')[1].behavior, Behavior.sniff);
    expect(meetSteps(Bond.play, 0.82, 'x')[1].behavior, Behavior.happy);
    expect(meetSteps(Bond.bestie, 0.5, '코코')[1].thought, '코코! 왔다!');
    expect(besideGuest(0.18), closeTo(0.34, 1e-9));
    expect(besideGuest(0.82), closeTo(0.66, 1e-9));
  });

  test('앉기류를 따라 할 땐 한 번 일어났다 앉아서 티가 난다', () {
    expect(mimicSteps(Trick.sit).map((s) => s.behavior), [
      Behavior.idle,
      Behavior.sit,
    ]);
    expect(mimicSteps(Trick.spin).map((s) => s.behavior), [Behavior.spin]);
  });

  test('만남 장면은 마지막에 meet 꼬리표가 있고, 밤엔 자는 애 옆에 조용히 앉는다', () {
    for (final b in Bond.values) {
      expect(meetSteps(b, 0.5, 'x').last.tag, StepTag.meet);
      expect(meetSteps(b, 0.5, 'x', night: true).last.tag, StepTag.meet);
    }
    final night = meetSteps(Bond.play, 0.82, '코코', night: true);
    expect(night.map((s) => s.behavior), [Behavior.walk, Behavior.sit]);
    expect(night.last.thought, '…자네. 옆에 있을래.');
    expect(
      meetSteps(Bond.bestie, 0.82, '코코', night: true).last.thought,
      '코코 자네. 옆에 있을래.',
    );
    // 낯선 애는 밤에도 멀찍이서 본다.
    expect(meetSteps(Bond.stranger, 0.82, 'x', night: true).first.targetX, 0.3);
  });

  test('따라 하기는 자리에서 하는 동작뿐이다', () {
    for (final t in Trick.values) {
      expect(
        mimicBehavior(t),
        isIn([
          Behavior.sit,
          Behavior.lieBeside,
          Behavior.spin,
          Behavior.jump,
          Behavior.sniff,
          Behavior.happy,
        ]),
      );
    }
    expect(mimicBehavior(Trick.spin), Behavior.spin);
  });

  test('창밖 지나가기는 낮에만, 두 분마다 일곱 초, 펫마다 때가 다르다', () {
    expect(windowPass(DateTime(2026, 10, 5, 9, 59), 1), isNull);
    expect(windowPass(DateTime(2026, 10, 5, 18), 1), isNull);
    var seen = 0;
    DateTime? first;
    for (var s = 0; s < 240; s++) {
      final t = DateTime(2026, 10, 5, 14).add(Duration(seconds: s));
      final p = windowPass(t, 1);
      if (p != null) {
        seen++;
        first ??= t;
        expect(p, inInclusiveRange(0, 1));
      }
    }
    expect(seen, 14);
    final other = windowPass(first!, 61);
    expect(other, isNull);
    // 초 밑 소수점도 쓴다. 300ms 뒤면 조금 더 지나가 있어야 한다(1초마다 뛰지 않게).
    final a = windowPass(first, 1)!;
    final b = windowPass(first.add(const Duration(milliseconds: 300)), 1)!;
    expect(b - a, closeTo(0.3 / 7, 1e-9));
  });

  test('어제 만난 애만 지나가고, 여럿이면 날마다 다른 애', () {
    final now = DateTime(2026, 10, 6, 14);
    expect(passerFor(cafeRegulars, const {}, now), isNull);
    final friends = {
      'coco': const Friendship(
        bond: Bond.sniff,
        days: 2,
        lastDay: '2026-10-05',
      ),
      'dubu': const Friendship(
        bond: Bond.stranger,
        days: 1,
        lastDay: '2026-10-03',
      ),
    };
    expect(passerFor(cafeRegulars, friends, now)?.id, 'coco');
    friends['bori'] = const Friendship(
      bond: Bond.play,
      days: 3,
      lastDay: '2026-10-05',
    );
    final ids = {
      for (var d = 6; d < 12; d++)
        passerFor(cafeRegulars, {
          for (final e in friends.entries)
            e.key: Friendship(
              bond: e.value.bond,
              days: e.value.days,
              lastDay: '2026-10-${(d - 1).toString().padLeft(2, '0')}',
            ),
        }, DateTime(2026, 10, d, 14))?.id,
    };
    expect(ids, containsAll(['coco', 'bori']));
  });

  test('잘 오는 요일인 애가 더 자주 온다. 다른 날에도 올 수는 있다', () {
    // 초코는 일요일만 잘 온다.
    var sundays = 0, weekdays = 0;
    for (var d = 1; d <= 84; d++) {
      final t = DateTime(2026, 10, 1).add(Duration(days: d, hours: 15));
      final here = guestsAt(t).any((g) => g.id == 'choco');
      if (t.weekday == 7) {
        if (here) sundays++;
      } else if (here) {
        weekdays++;
      }
    }
    expect(sundays / 12, greaterThan(weekdays / 72));
    expect(weekdays, greaterThan(0));
  });
}
