import 'dart:math';

/// 그날 있었던 일 하나. 일기 재료(events 테이블)와 같은 모양이다.
typedef DayEvent = ({DateTime at, String kind, String detail});

/// 일기에 먼저 담을 일. 클수록 앞선다.
const _weight = {
  'first_meeting': 10,
  'grow': 10,
  'show_off': 8,
  'walk': 8,
  'friend': 8,
  'recital': 8,
  'cuddle': 7,
  // 들어준 소원과 함께한 날 이정표, 한 번뿐인 줄(버릇·처음 그 자리에서 잔 날·친구한테 버릇이 옮은 날)은 그날 일기에 꼭 들어간다.
  'wish': 9,
  'together': 9,
  'quirk': 9,
  'spot': 9,
  'friend_habit': 9,
  'cafe': 7,
  'friend_trick': 5,
  'friend_window': 4,
  'daycare': 7,
  'daycare_miss': 6,
  'hospital': 6,
  'shop': 5,
  'treat': 4,
  'hospital_visit': 3,
  'shop_visit': 3,
  'homecam': 3,
  'snow': 8,
  'comfort': 7,
  'find': 7,
  'play': 6,
  'trick': 5,
  'trick_chain': 6,
  'greet': 5,
  'place': 4,
  'favorite': 4,
  'hide': 3,
  'door': 5,
  'door_take': 4,
  'friend_habit_gone': 6,
  'share': 7,
  'walk_spot': 5,
  'talk': 3,
  'feed': 2,
  'pet': 2,
  'weather': 1,
};

/// AI 없이 폰에서 쓰는 펫 일기. 그날 일 중 큰 것 넷까지 골라 시간 순서로 잇는다.
/// 일이 없으면 null. 지어내지 않고, 주인이 한 말은 옮기지 않는다.
String? localDiary(List<DayEvent> events, Random random) {
  final best = <String, DayEvent>{};
  for (final e in events) {
    final w = _weight[e.kind];
    if (w == null) continue;
    final had = best[e.kind];
    // 개인기는 처음 해낸 날이 더 크다.
    final first = e.kind == 'trick' && e.detail.contains('처음');
    if (had == null || first) best[e.kind] = e;
  }
  if (best.isEmpty) return null;
  int score(DayEvent e) =>
      (_weight[e.kind] ?? 0) +
      (e.kind == 'trick' && e.detail.contains('처음') ? 4 : 0);
  // 같은 때 일어난 일은 기록된 순서대로 둔다(반긴 뒤에 자랑).
  final order = {for (final (i, e) in events.indexed) e: i};
  final picked =
      (best.values.toList()..sort((a, b) => score(b).compareTo(score(a))))
          .take(4)
          .toList()
        ..sort((a, b) {
          final t = a.at.compareTo(b.at);
          return t != 0 ? t : order[a]!.compareTo(order[b]!);
        });
  final lines = <String>[];
  String? lastPart;
  for (final e in picked) {
    final part = _partOfDay(e.at);
    final text = _safe(e);
    lines.add(part == lastPart ? '$text.' : '$part $text.');
    lastPart = part;
  }
  lines.add(_closing(best.keys.toSet(), random));
  return lines.join(' ');
}

String _partOfDay(DateTime t) => switch (t.hour) {
  >= 5 && < 11 => '아침에',
  >= 11 && < 17 => '낮에',
  >= 17 && < 21 => '저녁에',
  _ => '밤에',
};

/// 대화 기록에는 주인이 한 말이 따옴표로 들어 있다. 일기에는 옮기지 않고, 그 뒤 펫이 한 일은 남긴다.
String _safe(DayEvent e) {
  final d = e.detail.trim().replaceAll(RegExp(r'[.。]+$'), '');
  if (e.kind != 'talk' || !d.contains('"')) return d;
  final rest = d.replaceFirst(RegExp(r'^주인이 ".*"라고 했다\.?\s*'), '');
  if (rest.isEmpty || rest.contains('"')) return '주인이 말을 걸어 줬다';
  return '주인이 말을 걸어 줬다. $rest';
}

/// 그날 일에 맞는 마무리가 있으면 그중에서, 없으면 무난한 말로.
String _closing(Set<String> kinds, Random random) {
  final fitting = [
    if (kinds.contains('play') ||
        kinds.contains('trick') ||
        kinds.contains('trick_chain'))
      '내일도 같이 놀고 싶다.',
    if (kinds.contains('walk')) '바깥 냄새가 아직 코에 남아 있다.',
    if (kinds.contains('cafe')) '카페에서 본 애들이 자꾸 생각난다.',
    if (kinds.contains('friend')) '내일도 그 애가 카페에 올까.',
    if (kinds.contains('daycare')) '유치원 친구들 냄새가 아직 몸에 남아 있다.',
    if (kinds.contains('recital')) '다음 발표회엔 뭘 보여 줄까.',
    if (kinds.contains('hospital') || kinds.contains('hospital_visit'))
      '병원은 무서웠지만 주인이 있어서 괜찮았다.',
    if (kinds.contains('shop') ||
        kinds.contains('treat') ||
        kinds.contains('shop_visit'))
      '내일도 간식 가게에 가고 싶다.',
    if (kinds.contains('comfort')) '주인 옆에 있을 수 있어서 다행이다.',
    if (kinds.contains('grow')) '몸이 커지니까 세상이 조금 작아 보인다.',
  ];
  final pool = fitting.isEmpty
      ? const ['오늘도 주인이 와서 좋았다.', '내일은 뭘 하고 놀까.']
      : fitting;
  return pool[random.nextInt(pool.length)];
}
