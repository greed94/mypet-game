import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';

void main() {
  test('발견물은 20개이고 이름과 id가 겹치지 않는다', () {
    expect(items, hasLength(20));
    expect(items.map((i) => i.id).toSet(), hasLength(20));
    for (final t in Taste.values) {
      expect(items.where((i) => i.taste == t), hasLength(5), reason: t.name);
    }
  });

  group('주머니 걸음', () {
    test('처음 읽을 때는 기준만 잡고 0걸음이다', () {
      expect(stepsSince(null, 5000), 0);
    });

    test('지난 값과의 차이만 쓴다', () {
      expect(stepsSince(1000, 4200), 3200);
    });

    test('재부팅으로 누적값이 줄면 지금 값 전체를 걸은 걸음으로 본다', () {
      expect(stepsSince(9000, 1200), 1200);
    });

    test('상한에 안 걸리면 1500걸음이 안 된 나머지를 다음 번으로 넘긴다', () {
      expect(nextStepBase(6200, 1200, 0), 5000);
      expect(nextStepBase(7400, 2400, 1), 6500);
      expect(nextStepBase(5000, 0, 0), 5000);
      // 상한에 걸려 줄인 만큼은 넘기지 않는다.
      expect(nextStepBase(30000, 25000, 3), 30000);
    });

    test('한 번 열 때 최대 3개, 하루 최대 5개', () {
      expect(pocketFinds(1499, 0), 0);
      expect(pocketFinds(3000, 0), 2);
      expect(pocketFinds(20000, 0), 3);
      expect(pocketFinds(20000, 4), 1);
      expect(pocketFinds(20000, 5), 0);
    });
  });

  group('산책', () {
    test('너무 짧으면 없고, 걸으면 최소 하나', () {
      expect(walkFinds(100, const Duration(minutes: 1)), 0);
      expect(walkFinds(400, const Duration(minutes: 2)), 1);
    });

    test('느긋하게 걸으면 하나 더', () {
      final fast = walkFinds(2400, const Duration(minutes: 20));
      final slow = walkFinds(2400, const Duration(minutes: 40));
      expect(slow, fast + 1);
    });

    test('걸음 권한이 없으면 시간으로 세고 최대 6개', () {
      expect(walkFinds(0, const Duration(minutes: 15)), 3);
      expect(walkFinds(50000, const Duration(minutes: 90)), 6);
    });
  });

  group('창틀', () {
    test('밤 11시~새벽 2시만, 같은 밤은 같은 키', () {
      expect(windowNight(DateTime(2026, 9, 26, 22, 59)), isNull);
      expect(windowNight(DateTime(2026, 9, 26, 23, 30)), '2026-9-26');
      expect(windowNight(DateTime(2026, 9, 27, 1, 50)), '2026-9-26');
      expect(windowNight(DateTime(2026, 9, 27, 2, 0)), isNull);
    });

    test('창틀에는 밤 물건만 떨어진다', () {
      final r = Random(1);
      for (var i = 0; i < 50; i++) {
        final item = pickItem(
          r,
          source: FindSource.window,
          now: DateTime(2026, 9, 26, 23),
          raining: false,
        );
        expect(item.pool, ItemPool.night);
      }
    });
  });

  test('비 물건은 비 올 때만, 계절 물건은 제철이 아니어도 가끔 나온다', () {
    final dry = DateTime(2026, 9, 26, 14);
    for (final i in items.where((i) => i.pool == ItemPool.rain)) {
      expect(
        findWeight(i, source: FindSource.walk, now: dry, raining: false),
        0,
      );
    }
    final spring = DateTime(2026, 4, 1, 14);
    final acorn = itemById('acorn')!;
    expect(
      findWeight(acorn, source: FindSource.walk, now: spring, raining: false),
      greaterThan(0),
    );
  });

  test('선물은 좋아하는 계열이 더 잘 나온다', () {
    final now = DateTime(2026, 9, 26, 14);
    final shiny = itemById('bottle_cap')!;
    final plain = findWeight(
      shiny,
      source: FindSource.pocket,
      now: now,
      raining: false,
    );
    final gift = findWeight(
      shiny,
      source: FindSource.gift,
      now: now,
      raining: false,
      like: Taste.shiny,
    );
    expect(gift, plain * 3);
  });

  test('위로 선물은 좋아하는 계열에서만 나온다', () {
    final r = Random(4);
    for (var i = 0; i < 60; i++) {
      final item = pickItem(
        r,
        source: FindSource.comfort,
        now: DateTime(2026, 9, 26, 14),
        raining: false,
        like: Taste.shiny,
      );
      expect(item.taste, Taste.shiny);
    }
  });

  test('취향은 펫마다 고정이고 좋아하는 것과 별로인 것이 다르다', () {
    expect(tasteFor(7), tasteFor(7));
    final (like, dislike) = tasteFor(7);
    expect(like, isNot(dislike));
  });

  group('방', () {
    test('놓인 게 없으면 방문하지 않는다', () {
      expect(chooseVisit(Random(1), const {}), isNull);
    });

    test('바닥의 공은 뛰어가서 신나 한다', () {
      final steps = chooseVisit(Random(1), const {'floor3': 'tennis_ball'})!;
      expect(steps.first.behavior, Behavior.run);
      expect(steps.first.targetX, slotById('floor3')!.walkX);
      expect(steps.last.behavior, Behavior.happy);
    });

    test('선반 물건은 밑에 가서 앉아 올려다본다', () {
      final steps = chooseVisit(Random(1), const {'shelf1': 'tennis_ball'})!;
      expect(steps.last.behavior, Behavior.sit);
    });

    test('좋아하는 계열을 더 자주 찾아간다', () {
      final r = Random(3);
      var liked = 0;
      for (var i = 0; i < 400; i++) {
        final s = chooseVisit(r, const {
          'floor1': 'acorn',
          'floor4': 'old_sock',
        }, like: Taste.round)!;
        if (s.first.targetX == slotById('floor1')!.walkX) liked++;
      }
      expect(liked, greaterThan(250));
    });

    test('좋아하는 물건이 선반에 있으면 가끔 러그 옆으로 옮긴다', () {
      Map<String, String>? moved;
      final r = Random(5);
      for (var i = 0; i < 20 && moved == null; i++) {
        moved = moveFavorite(r, const {'shelf1': 'acorn'}, Taste.round);
      }
      expect(moved, {'floor2': 'acorn'});
      expect(
        moveFavorite(Random(5), const {
          'shelf1': 'acorn',
          'floor2': 'old_sock',
        }, Taste.round),
        isNull,
      );
    });
  });

  test('받을 때 반응은 취향을 따른다', () {
    final acorn = itemById('acorn')!;
    expect(reactionTo(acorn, Taste.round, Taste.shiny), Reaction.love);
    expect(reactionTo(acorn, Taste.shiny, Taste.round), Reaction.meh);
    expect(reactionTo(acorn, Taste.shiny, Taste.smelly), Reaction.plain);
    expect(
      receiveThought(acorn, Reaction.love, Random(1)).runes.length,
      lessThanOrEqualTo(40),
    );
  });
}
