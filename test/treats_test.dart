import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/treats.dart';

void main() {
  const s = PetStats(mood: 50, hunger: 50, energy: 80, affection: 30);

  test('간식은 맛 갈래마다 둘씩 있고 id가 겹치지 않는다', () {
    expect(treats.map((t) => t.id).toSet().length, treats.length);
    for (final taste in Taste.values) {
      expect(treats.where((t) => t.taste == taste).length, 2);
    }
  });

  test('그날 진열장은 넷이고, 같은 날엔 같고, 날이 바뀌면 달라진다', () {
    final a = lineupOn(DateTime(2026, 10, 5, 9));
    expect(a.length, shopSlots.length);
    expect(a.map((t) => t.id).toSet().length, a.length);
    expect(
      lineupOn(DateTime(2026, 10, 5, 21)).map((t) => t.id),
      a.map((t) => t.id),
    );
    final days = {
      for (var d = 1; d <= 14; d++)
        lineupOn(DateTime(2026, 10, d)).map((t) => t.id).join(','),
    };
    expect(days.length, greaterThan(5));
  });

  test('펫은 좋아하는 갈래를 고르고, 없으면 싫어하는 갈래는 피한다', () {
    final lineup = [treats[6], treats[2], treats[0], treats[4]];
    expect(pickIndex(lineup, Taste.round, Taste.smelly), 2);
    expect(pickIndex(lineup, null, Taste.smelly), 1);
    expect(pickIndex([treats[6], treats[7]], Taste.round, Taste.smelly), 0);
  });

  test('좋아하는 간식은 크게 기뻐하고, 싫어하는 갈래는 냄새만 맡는다. 속마음은 40자 안쪽이다', () {
    final love = eatTreat(s, treats[0], Taste.round, Taste.smelly);
    expect(love.reaction, Reaction.love);
    expect(love.stats.mood, 60);
    expect(love.stats.hunger, 42);
    expect(love.steps.map((p) => p.behavior), [Behavior.eat, Behavior.happy]);
    // 손에서 받아 먹는 거라 밥그릇은 그리지 않는다.
    expect(love.steps.first.tag, StepTag.snack);

    final meh = eatTreat(s, treats[6], Taste.round, Taste.smelly);
    expect(meh.reaction, Reaction.meh);
    expect(meh.steps.first.behavior, Behavior.sniff);
    expect(meh.stats.mood, 51);

    final plain = eatTreat(s, treats[2], Taste.round, Taste.smelly);
    expect(plain.reaction, Reaction.plain);
    expect(plain.stats.mood, 55);

    for (final t in treats) {
      for (final p in eatTreat(s, t, t.taste, null).steps) {
        expect((p.thought ?? '').length, lessThanOrEqualTo(40));
      }
    }
  });

  test('주머니는 쉼표로 저장하고, 모르는 간식은 버린다', () {
    expect(pouchFrom(null), isEmpty);
    expect(pouchFrom(''), isEmpty);
    expect(pouchFrom('jerky,nope,cheese_ball'), ['jerky', 'cheese_ball']);
    expect(pouchTo([]), isNull);
    expect(pouchTo(['jerky', 'chicken']), 'jerky,chicken');
  });
}
