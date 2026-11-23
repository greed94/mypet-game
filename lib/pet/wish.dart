import 'dart:math';

import 'friends.dart';
import 'guest.dart';
import 'josa.dart';
import 'pet_rules.dart';
import 'recital.dart';
import 'spots.dart';
import 'tricks.dart';

/// 오늘의 소원. 펫의 하루에 하나, 규칙이 고르고 AI는 끼지 않는다.
/// 들어주면 그날 유난히 좋아하고, 안 들어줘도 아무 일 없다(벌·연속 기록·할 일 목록 없음).
enum WishKind { ball, treat, friend, kinder, recital, cuddle, trick }

class Wish {
  const Wish(this.kind, {this.target});

  final WishKind kind;

  /// 만나고 싶은 친구(손님 id)나 연습하고 싶은 개인기 이름. [WishKind.friend]·[WishKind.trick]만.
  final String? target;

  String encode() => target == null ? kind.name : '${kind.name}:$target';

  static Wish? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final i = s.indexOf(':');
    final name = i < 0 ? s : s.substring(0, i);
    final kind = WishKind.values.asNameMap()[name];
    if (kind == null) return null;
    return Wish(kind, target: i < 0 ? null : s.substring(i + 1));
  }
}

/// 쓰다듬어 달라는 소원은 이만큼 쓰다듬으면(연타는 한 번으로) 이뤄진다(기본값).
const cuddleWishPets = 3;

/// 오늘(펫의 하루) 카페에 한 번이라도 와 있을 친구들. 킁킁 사이부터.
/// 카페에 갈 때와 같은 계산(시간대 넷, 아는 강아지 포함)이라 소원 친구가 그날 꼭 한 번은 온다.
List<Guest> friendsAtCafeOn(
  DateTime day,
  List<Guest> known,
  Map<String, Friendship> friends,
) {
  final seen = <String, Guest>{};
  for (var i = 0; i < 4; i++) {
    final t = DateTime(day.year, day.month, day.day, dayStartHour + 6 * i);
    final guests = guestsAt(
      t,
      known: known,
      newcomers: {
        for (final g in known)
          if (newcomerAt(friends[g.id], t)) g.id,
      },
    );
    for (final g in guests) {
      if ((friends[g.id]?.bond.index ?? 0) >= Bond.sniff.index) {
        seen.putIfAbsent(g.id, () => g);
      }
    }
  }
  return seen.values.toList();
}

/// 연습하고 싶은 개인기: 배우는 중인 것 중 가장 많이 해낸 것, 없으면 별이 덜 찬 배운 것.
/// 물어와는 공이 있어야 해서 뺀다.
Trick? wishTrick(Map<Trick, TrickProgress> tricks) {
  // 칩 순서대로 보며 더 나을 때만 바꾼다(같으면 앞의 것).
  Trick? best(
    bool Function(TrickProgress) ok,
    int Function(TrickProgress) score,
  ) {
    Trick? b;
    for (final t in Trick.values) {
      final p = tricks[t];
      if (!t.chip || t == Trick.fetch || p == null || !ok(p)) continue;
      if (b == null || score(p) > score(tricks[b]!)) b = t;
    }
    return b;
  }

  return best((p) => p.successes > 0 && !p.learned, (p) => p.successes) ??
      best((p) => p.learned && p.stars < 3, (p) => -p.stars);
}

/// 오늘의 소원을 고른다. 같은 펫·같은 날·같은 상태면 늘 같다(고른 소원은 저장해 두고 그날 내내 쓴다).
/// 무게(기본값): 금요일 발표회 6, 카페 친구 3, 간식 3(배고프거나 주머니에 있으면, 아니면 1), 공 2, 쓰다듬기 2,
/// 개인기 연습 2(배우는 중이거나 별이 덜 찬 개인기가 있으면), 유치원 1.
/// [avoid]는 어제 소원의 종류. 다른 게 있으면 고르지 않는다(폰에서 이틀 연속 같은 소원이 나왔다).
Wish pickWish({
  required DateTime now,
  required int petId,
  required PetStats stats,
  required Map<Trick, TrickProgress> tricks,
  required Map<String, Friendship> friends,
  required List<Guest> known,
  required int pouch,
  WishKind? avoid,
}) {
  final day = petDate(now);
  final r = Random(stableHash('$petId/${dayKey(day)}'));
  final pals = friendsAtCafeOn(day, known, friends);
  final practice = wishTrick(tricks);
  final all = <(WishKind, double)>[
    if (recitalDay(now) && recitalSet(tricks).isNotEmpty) (WishKind.recital, 6),
    if (pals.isNotEmpty) (WishKind.friend, 3),
    (WishKind.treat, stats.hunger > 60 || pouch > 0 ? 3 : 1),
    (WishKind.ball, 2),
    (WishKind.cuddle, 2),
    if (practice != null) (WishKind.trick, 2),
    (WishKind.kinder, 1),
  ];
  final fresh = [
    for (final o in all)
      if (o.$1 != avoid) o,
  ];
  final options = fresh.isEmpty ? all : fresh;
  var roll = r.nextDouble() * options.fold(0.0, (a, o) => a + o.$2);
  var kind = options.last.$1;
  for (final (k, w) in options) {
    roll -= w;
    if (roll < 0) {
      kind = k;
      break;
    }
  }
  if (kind == WishKind.trick) return Wish(kind, target: practice!.name);
  if (kind != WishKind.friend) return Wish(kind);
  // 가장 가까운 애. 같으면 그날 정해진 대로.
  pals.sort((a, b) {
    final d = friends[b.id]!.bond.index - friends[a.id]!.bond.index;
    return d != 0 ? d : stableHash(a.id).compareTo(stableHash(b.id));
  });
  final top = [
    for (final g in pals)
      if (friends[g.id]!.bond == friends[pals.first.id]!.bond) g,
  ];
  return Wish(kind, target: top[r.nextInt(top.length)].id);
}

/// 아침에 띄우는 속마음. [friend]는 만나고 싶은 애를 부르는 말(이름이나 생김새).
String wishThought(Wish w, {String? friend}) => switch (w.kind) {
  WishKind.ball => '오늘은 공 던져 주면 좋겠다…',
  WishKind.treat => '오늘은 간식 하나만…',
  WishKind.friend => '오늘 ${friend ?? '그 애'} 만나고 싶다',
  WishKind.kinder => '유치원엔 누가 왔을까?',
  WishKind.recital => '오늘 발표회 날! 두근두근',
  WishKind.cuddle => '오늘은 많이 쓰다듬어 줘…',
  WishKind.trick => '오늘은 ${_trickName(w)} 연습하고 싶어',
};

String _trickName(Wish w) =>
    "'${Trick.values.asNameMap()[w.target]?.label ?? '개인기'}'";

/// 들어줬을 때 일기 재료.
String wishDoneLine(Wish w, {String? friend}) => switch (w.kind) {
  WishKind.ball => '오늘 소원이던 공놀이를 했다',
  WishKind.treat => '오늘 소원이던 간식을 먹었다',
  WishKind.friend => '오늘 소원이던 ${josa(friend ?? '그 애', '을/를')} 카페에서 만났다',
  WishKind.kinder => '오늘 소원이던 유치원에 갔다',
  WishKind.recital => '오늘 소원이던 발표회에서 도장을 받았다',
  WishKind.cuddle => '오늘 소원대로 주인이 많이 쓰다듬어 줬다',
  WishKind.trick => '오늘 소원이던 ${_trickName(w)} 연습을 했다',
};

/// AI에게 알려 줄 오늘 바라는 것(짧은 말). 친구 이름은 넣지 않는다.
String wishTopic(WishKind k) => switch (k) {
  WishKind.ball => '공놀이',
  WishKind.treat => '간식',
  WishKind.friend => '카페 친구 만나기',
  WishKind.kinder => '유치원 가기',
  WishKind.recital => '발표회',
  WishKind.cuddle => '쓰다듬어 주기',
  WishKind.trick => '개인기 연습',
};

/// 소원이 가리키는 장소. 동네 지도에 작게 표시한다.
Spot? wishSpot(Wish w) => switch (w.kind) {
  WishKind.friend => Spot.cafe,
  WishKind.kinder || WishKind.recital => Spot.kindergarten,
  WishKind.treat => Spot.treatShop,
  WishKind.ball || WishKind.cuddle || WishKind.trick => null,
};

/// 생각 풍선에 넣는 아이콘(assets/ui). 친구는 그 애 얼굴을 그린다.
String? wishIcon(WishKind k) => switch (k) {
  WishKind.ball => 'ball',
  WishKind.treat => 'bone',
  WishKind.kinder => 'smile',
  WishKind.recital => 'sparkle',
  WishKind.cuddle => 'heart',
  WishKind.trick => 'paw',
  WishKind.friend => null,
};
