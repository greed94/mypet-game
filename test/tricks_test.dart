import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

class _Fixed implements Random {
  _Fixed(this.value, [this.index = 0]);

  final double value;
  final int index;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => min(index, max - 1);

  @override
  bool nextBool() => false;
}

const friend = PetStats(mood: 65, hunger: 30, energy: 80, affection: 40);

extension on TrickTry {
  TrickProgress progressAfter(String day) => const TrickProgress(
    attempts: 2,
    successes: 2,
  ).practiced(success: success, today: day);
}

const today = '2026-09-28';
const yesterday = '2026-09-27';

void main() {
  group('parseCommand', () {
    Trick? trick(String text, [String name = '초코']) =>
        parseCommand(text, name)?.trick;

    test('이름·군말·문장부호가 붙어도 명령을 알아듣는다', () {
      expect(trick('앉아'), Trick.sit);
      expect(trick('초코야 앉아!'), Trick.sit);
      expect(trick('앉아 봐'), Trick.sit);
      expect(trick('앉아, 앉아'), Trick.sit);
      expect(trick('앉아 초코야'), Trick.sit);
      expect(trick('빨리 이리 와'), Trick.come);
      expect(trick('이리 와 봐'), Trick.come);
      expect(trick('엎드려요'), Trick.down);
      expect(trick('기다려'), Trick.wait);
      expect(trick('빙글빙글 돌아'), Trick.spin);
    });

    test('점프와 물어와도 알아듣는다', () {
      expect(trick('점프!'), Trick.jump);
      expect(trick('초코야 뛰어봐'), Trick.jump);
      expect(trick('폴짝폴짝'), Trick.jump);
      expect(trick('물어와'), Trick.fetch);
      expect(trick('공 가져와봐'), isNull);
      expect(trick('가져와봐'), Trick.fetch);
      expect(trick('갖고 와'), Trick.fetch);
    });

    test('이름만 부른 말은 명령이 아니다', () {
      expect(trick('돌아', '돌이'), isNull);
      expect(trick('돌아 앉아', '돌이'), Trick.sit);
      expect(parseCommand('뽀뽀야', '뽀뽀'), isNull);
      expect(parseCommand('빵!', '빵'), isNull);
      expect(parseEveryday('돌아!', '돌이'), Everyday.called);
    });

    test('아직 못 배우는 개인기는 이름만 알려 준다', () {
      expect(parseCommand('손', '초코'), (trick: null, word: '손'));
      expect(parseCommand('손 줘', '초코'), (trick: null, word: '손'));
      expect(parseCommand('빵야!', '초코'), (trick: null, word: '빵'));
    });

    test('명령이 섞인 문장이나 비슷한 말은 명령이 아니다', () {
      expect(parseCommand('오늘 회사에서 계속 앉아 있었어', '초코'), isNull);
      expect(parseCommand('와', '초코'), isNull);
      expect(parseCommand('앉아서 쉬어', '초코'), isNull);
      expect(parseCommand('배고파', '초코'), isNull);
      expect(parseCommand('자', '초코'), isNull);
      expect(parseCommand('초코야 안 자?', '초코'), isNull);
      expect(parseCommand('돌아와', '초코'), isNull);
      expect(parseCommand('기다려 줘', '초코'), isNull);
    });
  });

  group('parseEveryday', () {
    test('이름만 부르거나 생활 말을 하면 알아듣는다', () {
      expect(parseEveryday('초코야', '초코'), Everyday.called);
      expect(parseEveryday('초코야 초코야!', '초코'), Everyday.called);
      expect(parseEveryday('별아', '별이'), Everyday.called);
      expect(parseEveryday('잘 자', '초코'), Everyday.sleep);
      expect(parseEveryday('사랑해요', '초코'), Everyday.love);
      expect(parseEveryday('초코야 놀자!', '초코'), Everyday.play);
      expect(parseEveryday('산책 갈까?', '초코'), Everyday.walk);
      expect(parseEveryday('놀아 줘', '초코'), Everyday.play);
      expect(parseEveryday('뽀뽀', '초코'), Everyday.love);
      expect(parseEveryday('오늘 힘들었어', '초코'), isNull);
    });
  });

  group('trickChance', () {
    test('처음엔 반쯤 못 하고, 어려운 개인기일수록 더 못 한다', () {
      const fresh = TrickProgress();
      expect(
        trickChance(Trick.sit, fresh, friend, today: today),
        closeTo(0.35, 1e-9),
      );
      expect(
        trickChance(Trick.spin, fresh, friend, today: today),
        lessThan(trickChance(Trick.sit, fresh, friend, today: today)),
      );
    });

    test('자고 일어나면 같은 연습으로도 더 잘한다', () {
      const practiced = TrickProgress(attempts: 2, successes: 1, days: 1);
      final sameDay = trickChance(
        Trick.sit,
        const TrickProgress(attempts: 2, successes: 1, days: 1, lastDay: today),
        friend,
        today: today,
      );
      final nextDay = trickChance(
        Trick.sit,
        const TrickProgress(
          attempts: 2,
          successes: 1,
          days: 1,
          lastDay: yesterday,
        ),
        friend,
        today: today,
      );
      expect(nextDay, greaterThan(sameDay));
      expect(practiced.learned, isFalse);
    });

    test('배운 개인기는 거의 하고, 별 셋이면 실수가 드물다', () {
      const learned = TrickProgress(attempts: 5, successes: 3, days: 1);
      expect(
        trickChance(Trick.spin, learned, friend, today: today),
        greaterThanOrEqualTo(0.85),
      );
      const master = TrickProgress(attempts: 20, successes: 15, days: 3);
      expect(master.stars, 3);
      expect(trickChance(Trick.spin, master, friend, today: today), 0.97);
    });

    test('낯가리거나 배고프거나 기분이 나쁘면 덜 한다', () {
      const p = TrickProgress(attempts: 1, successes: 1, days: 1);
      final base = trickChance(Trick.sit, p, friend, today: today);
      expect(
        trickChance(Trick.sit, p, friend.copyWith(affection: 10), today: today),
        lessThan(base),
      );
      expect(
        trickChance(Trick.sit, p, friend.copyWith(hunger: 90), today: today),
        lessThan(base),
      );
      expect(
        trickChance(
          Trick.spin,
          const TrickProgress(),
          const PetStats(mood: 10, hunger: 90, energy: 80, affection: 0),
          today: today,
        ),
        0.1,
      );
    });
  });

  test('이름은 못 알아들으면 귀만 쫑긋하고, 세 번 알아들으면 배운다', () {
    final miss = tryTrick(
      Trick.name,
      const TrickProgress(),
      friend,
      today: today,
      misses: 0,
      random: _Fixed(0.99),
    );
    expect(miss.success, isFalse);
    expect(miss.steps.single.behavior, Behavior.idle);
    final hit = tryTrick(
      Trick.name,
      const TrickProgress(attempts: 2, successes: 2),
      friend,
      today: today,
      misses: 0,
      random: _Fixed(0),
    );
    expect(hit.learnedNow, isTrue);
    expect(hit.steps.first.behavior, Behavior.run);
    expect(hit.steps.last.thought, '내 이름이다! 나 알아!');
    expect(hit.steps.last.cue, Cue.chime);
    expect(Trick.name.chip, isFalse);
    expect(showOffTrick({Trick.name: hit.progressAfter(today)}, today), isNull);
  });

  test('별은 배운 뒤 연습한 날마다 하나씩 붙는다', () {
    var p = const TrickProgress();
    for (var i = 0; i < 3; i++) {
      p = p.practiced(success: true, today: '2026-09-26');
    }
    expect(p.learned, isTrue);
    expect(p.stars, 1);
    p = p.practiced(success: false, today: yesterday);
    expect(p.stars, 2);
    p = p.practiced(success: true, today: today);
    p = p.practiced(success: true, today: today);
    expect(p.days, 3);
    expect(p.stars, 3);
    expect(p.attempts, 6);
  });

  group('tryTrick', () {
    test('두 번 연달아 못 하면 세 번째엔 꼭 해낸다', () {
      final r = tryTrick(
        Trick.spin,
        const TrickProgress(attempts: 2),
        friend,
        today: today,
        misses: 2,
        random: _Fixed(0.99),
      );
      expect(r.success, isTrue);
      expect(r.steps.first.behavior, Behavior.spin);
      expect(r.steps.last.behavior, Behavior.happy);
    });

    test('세 번째 성공에서 배우고 처음 배운 소리가 난다', () {
      final r = tryTrick(
        Trick.sit,
        const TrickProgress(attempts: 3, successes: 2, days: 1),
        friend,
        today: today,
        misses: 0,
        random: _Fixed(0),
      );
      expect(r.learnedNow, isTrue);
      expect(r.steps.last.cue, Cue.chime);
    });

    test('지쳤으면 하지 않고 연습으로도 치지 않는다', () {
      final r = tryTrick(
        Trick.sit,
        const TrickProgress(),
        friend.copyWith(energy: 5),
        today: today,
        misses: 5,
        random: _Fixed(0),
      );
      expect(r.counted, isFalse);
      expect(r.success, isFalse);
      expect(r.steps.single.behavior, Behavior.lieBeside);
    });

    test('못 하면 딴청을 피우거나, 아는 개인기를 대신 해 본다', () {
      final sniff = tryTrick(
        Trick.down,
        const TrickProgress(),
        friend,
        today: today,
        misses: 0,
        random: _Fixed(0.99),
      );
      expect(sniff.success, isFalse);
      expect(sniff.steps.single.behavior, Behavior.sniff);
      final wrong = tryTrick(
        Trick.down,
        const TrickProgress(),
        friend,
        today: today,
        misses: 0,
        random: _Fixed(0.99, 2),
        known: [Trick.sit, Trick.down],
      );
      expect(wrong.success, isFalse);
      expect(wrong.steps.first.behavior, Behavior.sit);
      expect(wrong.steps.first.thought, '이거지?');
      // 앉아를 시켰는데 기다려(같은 앉은 자세)를 하면 해낸 것처럼 보인다.
      final notSame = tryTrick(
        Trick.sit,
        const TrickProgress(),
        friend,
        today: today,
        misses: 0,
        random: _Fixed(0.99, 2),
        known: [Trick.wait, Trick.spin],
      );
      expect(notSame.steps.first.behavior, Behavior.spin);
      final confused = tryTrick(
        Trick.sit,
        const TrickProgress(),
        friend,
        today: today,
        misses: 0,
        random: _Fixed(0.99, 1),
      );
      expect(confused.steps.single.behavior, isNot(Behavior.sit));
    });
  });

  test('어제 연습해서 해낸 개인기 중 가장 많이 해낸 걸 자랑한다', () {
    expect(
      showOffTrick({
        Trick.sit: const TrickProgress(
          attempts: 4,
          successes: 3,
          days: 1,
          lastDay: yesterday,
        ),
        Trick.spin: const TrickProgress(
          attempts: 9,
          successes: 5,
          days: 2,
          lastDay: yesterday,
        ),
        Trick.down: const TrickProgress(
          attempts: 9,
          successes: 9,
          days: 2,
          lastDay: '2026-09-20',
        ),
        Trick.wait: const TrickProgress(attempts: 2, lastDay: yesterday),
      }, yesterday),
      Trick.spin,
    );
    expect(showOffTrick({}, yesterday), isNull);
  });
}
