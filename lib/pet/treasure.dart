import 'dart:math';

import 'pet_rules.dart';

/// 강아지 취향 계열. 강아지마다 좋아하는 것 하나, 별로인 것 하나가 규칙으로 정해진다.
enum Taste { round, rustle, shiny, smelly }

/// 방에 놓였을 때 강아지가 그 물건으로 하는 일.
enum ItemUse { play, rest, sniff, look }

/// 어디서 잘 나오는지. 계절은 잠그지 않고 확률만 바꾼다(놓쳤다는 느낌을 만들지 않으려고).
enum ItemPool { common, autumn, rain, night }

/// comfort는 지친 말 다음에 가져오는 위로 선물. 좋아하는 계열에서만 고른다.
/// friend는 카페 단짝이 두고 간 것. 그 애가 좋아하는 계열에서 고른다.
/// hidden은 가족이 되기 전까지 방석 밑에 숨겨 뒀다가 가족이 된 날 꺼내 준 것. 제일 아끼는 거라 좋아하는 계열에서만.
enum FindSource { pocket, walk, window, gift, comfort, friend, hidden }

class Item {
  const Item(
    this.id,
    this.name,
    this.taste,
    this.pool,
    this.use, {
    this.rare = false,
  });

  final String id;
  final String name;
  final Taste taste;
  final ItemPool pool;
  final ItemUse use;
  final bool rare;
}

/// 순서가 assets/items/items.png 의 칸 순서다(가로 10칸, 16×16).
const items = <Item>[
  Item('bottle_cap', '병뚜껑', Taste.shiny, ItemPool.common, ItemUse.play),
  Item('tennis_ball', '테니스공', Taste.round, ItemPool.common, ItemUse.play),
  Item('old_sock', '헌 양말', Taste.smelly, ItemPool.common, ItemUse.rest),
  Item(
    'clover',
    '네잎클로버',
    Taste.rustle,
    ItemPool.common,
    ItemUse.look,
    rare: true,
  ),
  Item('maple_leaf', '단풍잎', Taste.rustle, ItemPool.autumn, ItemUse.rest),
  Item('ginkgo_leaf', '은행잎', Taste.rustle, ItemPool.autumn, ItemUse.look),
  Item('acorn', '도토리', Taste.round, ItemPool.autumn, ItemUse.play),
  Item('pinecone', '솔방울', Taste.round, ItemPool.autumn, ItemUse.play),
  Item('chestnut', '밤송이', Taste.smelly, ItemPool.autumn, ItemUse.sniff),
  Item('foxtail', '강아지풀', Taste.rustle, ItemPool.autumn, ItemUse.look),
  Item('cosmos', '코스모스 꽃잎', Taste.smelly, ItemPool.autumn, ItemUse.rest),
  Item(
    'feather',
    '참새 깃털',
    Taste.rustle,
    ItemPool.autumn,
    ItemUse.look,
    rare: true,
  ),
  Item('red_berry', '빨간 열매', Taste.round, ItemPool.autumn, ItemUse.sniff),
  Item('twig', '나뭇가지', Taste.smelly, ItemPool.autumn, ItemUse.sniff),
  Item('snail_shell', '달팽이 껍데기', Taste.round, ItemPool.rain, ItemUse.look),
  Item('pebble', '반들 조약돌', Taste.shiny, ItemPool.rain, ItemUse.look),
  Item(
    'rain_button',
    '노란 우비 단추',
    Taste.shiny,
    ItemPool.rain,
    ItemUse.play,
    rare: true,
  ),
  Item('moon_piece', '달빛 조각', Taste.shiny, ItemPool.night, ItemUse.look),
  Item(
    'star_piece',
    '별 조각',
    Taste.shiny,
    ItemPool.night,
    ItemUse.look,
    rare: true,
  ),
  Item('evening_primrose', '달맞이꽃', Taste.smelly, ItemPool.night, ItemUse.sniff),
];

Item? itemById(String id) {
  for (final i in items) {
    if (i.id == id) return i;
  }
  return null;
}

int itemIndex(Item item) => items.indexOf(item);

String poolLabel(ItemPool p) => switch (p) {
  ItemPool.common => '늘 있는 것',
  ItemPool.autumn => '가을',
  ItemPool.rain => '비 오는 날',
  ItemPool.night => '밤 창틀',
};

/// 주머니 걸음. 앱을 열 때 폰 누적 걸음을 한 번 읽고 지난 값과 뺀다.
/// 재부팅하면 누적값이 0부터 다시 쌓이므로, 줄었으면 지금 값 전체를 그동안 걸은 걸음으로 본다.
int stepsSince(int? last, int now) {
  if (last == null) return 0;
  return now >= last ? now - last : now;
}

const pocketStepsPerFind = 1500, pocketPerOpen = 3, pocketPerDay = 5;

/// 상한에 닿지 않았으면 아직 발견물이 되지 않은 걸음을 다음 수집까지 남긴다.
int remainingPocketSteps(int steps, int finds) =>
    finds == steps ~/ pocketStepsPerFind ? steps % pocketStepsPerFind : 0;

/// v33까지 사용한 차감식 기준. 예전 형식의 기준을 다루는 호출자도 같은 규칙을 쓴다.
int nextStepBase(int total, int steps, int finds) =>
    total - remainingPocketSteps(steps, finds);

int pocketFinds(int steps, int foundToday) => min(
  min(steps ~/ pocketStepsPerFind, pocketPerOpen),
  max(0, pocketPerDay - foundToday),
);

/// 걸음이 많을수록 더 줍고, 느긋하게 걸으면(킁킁 시간이 길면) 하나 더 줍는다.
/// 걸음 권한이 없으면 시간만으로 센다.
int walkFinds(int steps, Duration length) {
  final minutes = length.inMinutes;
  if (steps < 300 && minutes < 3) return 0;
  var n = steps > 0 ? steps ~/ 600 : minutes ~/ 5;
  if (steps > 0 && minutes > 0 && steps / minutes < 80) n++;
  return n.clamp(1, 6);
}

/// 밤 11시~새벽 2시에 열면 창틀에 하나가 떨어진다. 같은 밤에는 한 번뿐이라 밤의 날짜를 키로 쓴다.
String? windowNight(DateTime now) {
  if (now.hour >= 2 && now.hour < 23) return null;
  final night = now.hour < 2 ? now.subtract(const Duration(days: 1)) : now;
  return '${night.year}-${night.month}-${night.day}';
}

bool _isAutumn(DateTime t) => t.month >= 9 && t.month <= 11;
bool _isDark(DateTime t) => t.hour >= 20 || t.hour < 6;

double findWeight(
  Item item, {
  required FindSource source,
  required DateTime now,
  required bool raining,
  Taste? like,
}) {
  if (source == FindSource.window) {
    return item.pool == ItemPool.night ? (item.rare ? 0.25 : 1) : 0;
  }
  var w = switch (item.pool) {
    ItemPool.common => 0.6,
    ItemPool.autumn => _isAutumn(now) ? 1.0 : 0.2,
    ItemPool.rain => raining ? 1.4 : 0.0,
    ItemPool.night => _isDark(now) && source == FindSource.walk ? 0.5 : 0.0,
  };
  if (item.rare) w *= source == FindSource.walk ? 0.3 : 0.12;
  if ((source == FindSource.comfort || source == FindSource.hidden) &&
      like != null &&
      item.taste != like) {
    return 0;
  }
  if ((source == FindSource.gift || source == FindSource.friend) &&
      item.taste == like) {
    w *= 3;
  }
  return w;
}

Item pickItem(
  Random random, {
  required FindSource source,
  required DateTime now,
  required bool raining,
  Taste? like,
}) {
  final weights = [
    for (final i in items)
      findWeight(i, source: source, now: now, raining: raining, like: like),
  ];
  var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
  for (var i = 0; i < items.length; i++) {
    roll -= weights[i];
    if (roll < 0) return items[i];
  }
  return items.first;
}

/// 좋아하는 것과 별로인 것. 펫마다 한 번 정해지면 바뀌지 않게 펫 고유값으로 섞는다.
(Taste, Taste) tasteFor(int seed) {
  final kinds = [...Taste.values]..shuffle(Random(seed));
  return (kinds[0], kinds[1]);
}

enum Reaction { love, meh, plain }

Reaction reactionTo(Item item, Taste? like, Taste? dislike) {
  if (item.taste == like) return Reaction.love;
  if (item.taste == dislike) return Reaction.meh;
  return Reaction.plain;
}

enum SlotArea { floor, shelf, sill }

class Slot {
  const Slot(this.id, this.area, this.walkX, this.label);

  final String id;
  final SlotArea area;

  /// 강아지가 이 물건에 가서 설 바닥 위치(0~1). 입에 문 물건이 방 밖으로 잘리지 않게 가장자리는 피한다.
  /// 그림 위치는 게임이 정한다.
  final double walkX;
  final String label;
}

const slots = <Slot>[
  Slot('floor1', SlotArea.floor, 0.28, '바닥 1'),
  Slot('floor2', SlotArea.floor, 0.46, '바닥 2'),
  Slot('floor3', SlotArea.floor, 0.64, '바닥 3'),
  Slot('floor4', SlotArea.floor, 0.84, '바닥 4'),
  Slot('shelf1', SlotArea.shelf, 0.1, '문 위 선반 1'),
  Slot('shelf2', SlotArea.shelf, 0.22, '문 위 선반 2'),
  Slot('sill1', SlotArea.sill, 0.72, '창턱 1'),
  Slot('sill2', SlotArea.sill, 0.84, '창턱 2'),
];

Slot? slotById(String id) {
  for (final s in slots) {
    if (s.id == id) return s;
  }
  return null;
}

/// 방에 놓인 물건이 있으면 가끔 그리로 간다. 좋아하는 계열은 자주, 별로인 계열은 드물게.
List<PetStep>? chooseVisit(
  Random random,
  Map<String, String> placed, {
  Taste? like,
  Taste? dislike,
}) {
  final spots = <(Slot, Item)>[
    for (final e in placed.entries)
      if (slotById(e.key) case final slot?)
        if (itemById(e.value) case final item?) (slot, item),
  ];
  if (spots.isEmpty) return null;
  final weights = [
    for (final (_, item) in spots)
      item.taste == like ? 3.0 : (item.taste == dislike ? 0.3 : 1.0),
  ];
  var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
  var pick = spots.last;
  for (var i = 0; i < spots.length; i++) {
    roll -= weights[i];
    if (roll < 0) {
      pick = spots[i];
      break;
    }
  }
  final (slot, item) = pick;
  if (slot.area != SlotArea.floor) {
    return [
      PetStep(Behavior.walk, 6, targetX: slot.walkX),
      const PetStep(Behavior.sit, 6),
    ];
  }
  return switch (item.use) {
    ItemUse.play => [
      PetStep(Behavior.run, 4, targetX: slot.walkX),
      const PetStep(Behavior.happy, 3),
    ],
    ItemUse.rest => [
      PetStep(Behavior.walk, 6, targetX: slot.walkX),
      const PetStep(Behavior.lieBeside, 10),
    ],
    ItemUse.sniff => [
      PetStep(Behavior.walk, 6, targetX: slot.walkX),
      const PetStep(Behavior.sniff, 4),
    ],
    ItemUse.look => [
      PetStep(Behavior.walk, 6, targetX: slot.walkX),
      const PetStep(Behavior.sit, 6),
    ],
  };
}

/// 오래 비웠다 돌아오면, 좋아하는 물건이 선반·창턱에 있을 때 가끔 제 자리(러그 옆 바닥)로 옮겨 둔다.
/// 옮길 게 없거나 자리가 차 있으면 null.
Map<String, String>? moveFavorite(
  Random random,
  Map<String, String> placed,
  Taste? like,
) {
  const home = 'floor2';
  if (like == null || placed.containsKey(home) || random.nextDouble() > 0.3) {
    return null;
  }
  for (final e in placed.entries) {
    final slot = slotById(e.key), item = itemById(e.value);
    if (slot == null || item == null) continue;
    if (slot.area != SlotArea.floor && item.taste == like) {
      return {...placed}
        ..remove(e.key)
        ..[home] = e.value;
    }
  }
  return null;
}

/// 지치거나 속상하다는 말. 위기 표현보다 약한 단계라 상담 안내 없이 다음에 열 때 선물로만 답한다.
/// AI가 꺼져 있어도 돌아가야 해서 폰 안 단어로 판단한다.
/// 지친 말. 낱말 안에서만 찾는다(띄어쓰기를 다 지우고 찾으면 '강아지 친구'가 '지친'으로 걸렸다).
/// '기운 없어'처럼 띄어 쓰는 말만 붙여서 본다.
bool needsComfort(String text) {
  final parts = text.split(RegExp(r'\s+'));
  if (text.replaceAll(RegExp(r'\s'), '').contains('기운없')) return true;
  const words = [
    '힘들',
    '힘드',
    '지쳤',
    '지친',
    '지쳐',
    '우울',
    '슬퍼',
    '슬프',
    '속상',
    '외로',
    '눈물',
    '울었',
    '울고',
    '서러',
    '괴로',
    '스트레스',
    '짜증',
    '피곤',
  ];
  return words.any((w) => parts.any((p) => p.contains(w)));
}

/// 주인 얘기가 아닌 지친 말: 펫에게 묻는 말("외로웠지?"), 아니라는 말("안 힘들어"), 하지 말라는 말("슬퍼하지 마").
bool askingOrDenying(String text) {
  final t = text.trim();
  const feeling =
      r'(?:힘들|힘드|지쳤|지친|지쳐|지치|우울|슬퍼|슬프|속상|외로|외롭|눈물|울었|울고|서러|괴로|스트레스|짜증|피곤|기운\s*없)';
  // 다른 낱말의 '안'이나 다른 행동의 부정은 주인의 지친 마음을 지우지 않는다.
  return t.endsWith('?') ||
      RegExp(r'(^|\s)안\s*' + feeling).hasMatch(t) ||
      RegExp(feeling + r'[^\s,.!?]*?지(?:는|도|가)?\s*(?:않|마|말)').hasMatch(t);
}

/// 받을 때 속마음. 폰 안 문구라 AI가 없어도 된다.
String receiveThought(Item item, Reaction r, Random random) {
  final lines = switch (r) {
    Reaction.love => switch (item.taste) {
      Taste.round => ['동글동글… 내 거야!', '이거 굴리고 싶어.'],
      Taste.rustle => ['바스락바스락, 좋아!', '이 소리 너무 좋아.'],
      Taste.shiny => ['반짝반짝… 보물이다!', '이거 내 보물 할래.'],
      Taste.smelly => ['킁킁… 냄새 최고야.', '이 냄새 계속 맡을래.'],
    },
    Reaction.meh => ['…이건 주인 줄게.', '음, 이건 별로야.'],
    Reaction.plain => ['주워 왔어. 받아.', '이거 봐, 찾았어.'],
  };
  return lines[random.nextInt(lines.length)];
}
