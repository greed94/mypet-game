import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/guest.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/pet/wish.dart';

const _calm = PetStats(mood: 60, hunger: 30, energy: 80, affection: 40);
const _learned = TrickProgress(attempts: 3, successes: 3, days: 1);

Wish _pick(
  DateTime now, {
  int petId = 1,
  PetStats stats = _calm,
  Map<Trick, TrickProgress> tricks = const {},
  Map<String, Friendship> friends = const {},
  int pouch = 0,
}) => pickWish(
  now: now,
  petId: petId,
  stats: stats,
  tricks: tricks,
  friends: friends,
  known: const [],
  pouch: pouch,
);

void main() {
  test('같은 펫·같은 날(펫의 하루)이면 같은 소원, 날이 바뀌면 여러 가지가 나온다', () {
    final morning = _pick(DateTime(2026, 10, 6, 8)).encode();
    expect(_pick(DateTime(2026, 10, 6, 22)).encode(), morning);
    // 새벽 4시는 아직 전날이다.
    expect(_pick(DateTime(2026, 10, 7, 4)).encode(), morning);
    final kinds = {
      for (var d = 0; d < 60; d++)
        _pick(DateTime(2026, 10, 1).add(Duration(days: d, hours: 9))).kind,
    };
    expect(
      kinds,
      containsAll([
        WishKind.ball,
        WishKind.treat,
        WishKind.cuddle,
        WishKind.kinder,
      ]),
    );
    // 친구가 없으면 친구 소원은 없다. 금요일이어도 배운 개인기가 없으면 발표회 소원은 없다.
    expect(kinds, isNot(contains(WishKind.friend)));
    expect(kinds, isNot(contains(WishKind.recital)));
  });

  test('어제와 같은 종류는 피한다(다른 게 있으면). 피해도 같은 날엔 늘 같다', () {
    for (var d = 0; d < 60; d++) {
      final t = DateTime(2026, 10, 1).add(Duration(days: d, hours: 9));
      for (final k in [WishKind.ball, WishKind.treat, WishKind.cuddle]) {
        final a = pickWish(
          now: t,
          petId: 1,
          stats: _calm,
          tricks: const {},
          friends: const {},
          known: const [],
          pouch: 0,
          avoid: k,
        );
        expect(a.kind, isNot(k));
        final b = pickWish(
          now: t,
          petId: 1,
          stats: _calm,
          tricks: const {},
          friends: const {},
          known: const [],
          pouch: 0,
          avoid: k,
        );
        expect(b.encode(), a.encode());
      }
    }
  });

  test('금요일에 배운 개인기가 있으면 발표회 소원이 자주 나온다', () {
    var recital = 0, fridays = 0;
    for (var d = 0; d < 140; d++) {
      final t = DateTime(2026, 10, 1).add(Duration(days: d, hours: 9));
      if (t.weekday != DateTime.friday) continue;
      fridays++;
      final w = _pick(t, tricks: {Trick.sit: _learned});
      if (w.kind == WishKind.recital) recital++;
    }
    expect(recital / fridays, greaterThan(0.25));
  });

  test('친구 소원은 그날 카페에 한 번은 오는 킁킁 사이 넘는 애다', () {
    final friends = {
      for (final g in cafeRegulars)
        g.id: const Friendship(bond: Bond.play, days: 3, lastDay: 'x'),
    };
    var found = 0;
    for (var d = 0; d < 40; d++) {
      final t = DateTime(2026, 10, 1).add(Duration(days: d, hours: 9));
      final w = _pick(t, friends: friends);
      if (w.kind != WishKind.friend) continue;
      found++;
      final day = petDate(t);
      final present = friendsAtCafeOn(day, const [], friends).map((g) => g.id);
      expect(present, contains(w.target));
    }
    expect(found, greaterThan(0));
    // 낯선 애뿐이면 친구 소원은 없다.
    final strangers = {
      for (final g in cafeRegulars)
        g.id: const Friendship(bond: Bond.stranger, days: 1, lastDay: 'x'),
    };
    for (var d = 0; d < 30; d++) {
      final t = DateTime(2026, 10, 1).add(Duration(days: d, hours: 9));
      expect(_pick(t, friends: strangers).kind, isNot(WishKind.friend));
    }
  });

  test('배고프거나 주머니에 간식이 있으면 간식 소원이 더 잦다', () {
    int count(PetStats s, int pouch) {
      var n = 0;
      for (var id = 0; id < 300; id++) {
        if (_pick(
              DateTime(2026, 10, 6, 9),
              petId: id,
              stats: s,
              pouch: pouch,
            ).kind ==
            WishKind.treat) {
          n++;
        }
      }
      return n;
    }

    final full = count(_calm, 0);
    expect(count(_calm.copyWith(hunger: 80), 0), greaterThan(full));
    expect(count(_calm, 2), greaterThan(full));
  });

  test('소원은 저장했다 그대로 되읽힌다', () {
    for (final w in [
      const Wish(WishKind.ball),
      const Wish(WishKind.friend, target: 'known_1_0'),
    ]) {
      final back = Wish.decode(w.encode())!;
      expect(back.kind, w.kind);
      expect(back.target, w.target);
    }
    expect(Wish.decode(null), isNull);
    expect(Wish.decode('nope'), isNull);
  });

  test('속마음·일기 문장은 40자 안쪽이고, 장소를 가리키는 소원은 지도에 표시할 곳이 있다', () {
    for (final k in WishKind.values) {
      final w = Wish(k, target: 'coco');
      expect(
        wishThought(w, friend: '가나다라마바사아자차').length,
        lessThanOrEqualTo(40),
      );
      expect(wishDoneLine(w, friend: '코코'), startsWith('오늘 소원'));
      expect(wishIcon(k) != null || k == WishKind.friend, isTrue);
    }
    expect(wishSpot(const Wish(WishKind.friend)), Spot.cafe);
    expect(wishSpot(const Wish(WishKind.recital)), Spot.kindergarten);
    expect(wishSpot(const Wish(WishKind.ball)), isNull);
    expect(
      wishDoneLine(const Wish(WishKind.friend), friend: '코코'),
      contains('코코를'),
    );
  });

  test('개인기 연습 소원: 배우는 중인 것 중 가장 많이 해낸 것, 없으면 별이 덜 찬 배운 것', () {
    expect(
      wishTrick({
        Trick.sit: const TrickProgress(attempts: 3, successes: 1, days: 1),
        Trick.spin: const TrickProgress(attempts: 4, successes: 2, days: 1),
        Trick.down: _learned,
      }),
      Trick.spin,
    );
    expect(
      wishTrick({
        Trick.down: const TrickProgress(attempts: 6, successes: 6, days: 2),
        Trick.sit: _learned,
        Trick.fetch: const TrickProgress(attempts: 2, successes: 1, days: 1),
      }),
      Trick.sit,
    );
    const three = TrickProgress(attempts: 9, successes: 9, days: 3);
    expect(wishTrick({Trick.sit: three}), isNull);
    expect(wishTrick(const {}), isNull);
  });

  test('연습할 개인기가 있으면 개인기 소원도 나오고, 말과 아이콘이 맞다', () {
    final tricks = {
      Trick.spin: const TrickProgress(attempts: 4, successes: 2, days: 1),
    };
    final wishes = [
      for (var d = 0; d < 60; d++)
        _pick(
          DateTime(2026, 10, 1).add(Duration(days: d, hours: 9)),
          tricks: tricks,
        ),
    ];
    final practice = wishes.where((w) => w.kind == WishKind.trick).toList();
    expect(practice, isNotEmpty);
    expect(practice.map((w) => w.target).toSet(), {'spin'});
    final w = practice.first;
    expect(Wish.decode(w.encode())!.target, 'spin');
    expect(wishThought(w), "오늘은 '돌아' 연습하고 싶어");
    expect(wishDoneLine(w), "오늘 소원이던 '돌아' 연습을 했다");
    expect(wishTopic(WishKind.trick), '개인기 연습');
    expect(wishSpot(w), isNull);
    expect(wishIcon(WishKind.trick), 'paw');
    expect([
      for (var d = 0; d < 60; d++)
        _pick(DateTime(2026, 10, 1).add(Duration(days: d, hours: 9))).kind,
    ], isNot(contains(WishKind.trick)));
  });

  test('오늘 소원을 묻는 말', () {
    for (final s in ['뭐 하고 싶어?', '콩이야 소원이 뭐야', '오늘 뭐 하고 싶어요', '뭐 해 줄까']) {
      expect(parseEveryday(s, '콩이'), Everyday.wish, reason: s);
    }
    expect(parseEveryday('나도 산책하고 싶어', '콩이'), isNot(Everyday.wish));
  });
}
