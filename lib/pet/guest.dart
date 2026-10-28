import 'dart:math';

import 'pet_rules.dart';
import 'treasure.dart';

/// 카페에 오는 다른 강아지. 그림은 모양 틀 하나에 색만 바꿔 쓴다(새 시트 없음).
class Guest {
  const Guest({
    required this.id,
    required this.shape,
    required this.look,
    required this.main,
    required this.second,
    required this.marking,
    this.accent = 0xFF4FA3D1,
    this.puppy = false,
    this.taste = Taste.round,
    this.days = const {},
  });

  final String id;
  final String shape;

  /// 이름을 붙이기 전에 부르는 말. 견종이 아니라 생김새로("갈색 꼬리 말린 애").
  final String look;

  /// 좋아하는 것. 단짝이 되면 이 갈래의 물건을 두고 간다.
  final Taste taste;

  /// 잘 오는 요일(1=월 … 7=일). 비면 아무 날이나. 안 오는 날은 없고 확률만 다르다.
  final Set<int> days;

  /// 아기 그림으로 그린다(유치원 친구).
  final bool puppy;
  final int main;
  final int second;
  final int marking;
  final int accent;
}

/// 카페 단골.
const cafeRegulars = [
  Guest(
    id: 'coco',
    shape: 'shiba',
    look: '꼬리 말린 갈색 애',
    main: 0xFFB5703A,
    second: 0xFFF3E6D2,
    marking: 0xFF6B3F22,
    taste: Taste.round,
    days: {1, 3, 5},
  ),
  Guest(
    id: 'dubu',
    shape: 'maltese',
    look: '분홍 목걸이 흰 애',
    main: 0xFFFFFBF2,
    second: 0xFFF1E6D6,
    marking: 0xFFFFFBF2,
    accent: 0xFFE8A0B4,
    taste: Taste.rustle,
    days: {2, 4, 6},
  ),
  Guest(
    id: 'bori',
    shape: 'corgi',
    look: '다리 짧은 노란 애',
    main: 0xFFE39A4C,
    second: 0xFFFFF4E0,
    marking: 0xFFE39A4C,
    accent: 0xFF6AAF5E,
    taste: Taste.shiny,
    days: {6, 7},
  ),
  Guest(
    id: 'mong',
    shape: 'pug',
    look: '얼굴 까만 애',
    main: 0xFFD9B98A,
    second: 0xFFF1E3C8,
    marking: 0xFF3A2A20,
    accent: 0xFFD64040,
    taste: Taste.smelly,
    days: {1, 2, 3, 4, 5},
  ),
  Guest(
    id: 'choco',
    shape: 'retriever',
    look: '덩치 큰 초코색 애',
    main: 0xFF6B4A2E,
    second: 0xFF9A7452,
    marking: 0xFF6B4A2E,
    accent: 0xFFF2C14E,
    taste: Taste.round,
    days: {7},
  ),
];

/// 주인이 데려올 수 있는 아는 강아지 수(기본값).
const maxKnownDogs = 4;

/// 아는 강아지 하나가 한 시간대(6시간)에 카페에 와 있을 확률(기본값).
/// 아직 못 만났거나 오늘 처음 만난 애는 꼭 온다(friends.dart newcomerAt).
const knownChance = 0.5;

/// 한 시간대에 아는 강아지가 앉는 자리 수의 상한(기본값). 단골 자리도 남긴다.
const maxKnownSeats = 2;

/// 앱을 다시 켜도 같은 값. String.hashCode는 실행마다 같다는 보장이 없다.
int stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h;
}

/// 아는 강아지의 이름을 지웠을 때 부르는 말.
const _knownLook = {
  'papillon': '귀가 큰 애',
  'maltese': '털이 복슬한 애',
  'shiba': '꼬리 말린 애',
  'retriever': '덩치 큰 애',
  'corgi': '다리 짧은 애',
  'pug': '얼굴 납작한 애',
};

const _knownAccents = [
  0xFF4FA3D1,
  0xFF6AAF5E,
  0xFFF2C14E,
  0xFFE8A0B4,
  0xFF9B7FD1,
];

/// 주인이 데려온 아는 강아지(친구·가족네). 생김새는 주인이 고른다.
/// 목걸이 색은 털색으로 정해 데려오기 화면의 미리보기와 같고, 좋아하는 것은 id로 정한다.
Guest knownGuest({
  required String id,
  required String shape,
  required int main,
  required int second,
  required int marking,
  bool puppy = false,
}) {
  final h = stableHash(id);
  return Guest(
    id: id,
    shape: shape,
    look: _knownLook[shape] ?? '친구네 강아지',
    main: main,
    second: second,
    marking: marking,
    accent: _knownAccents[(main & 0xFFFFFF) % _knownAccents.length],
    puppy: puppy,
    taste: Taste.values[(h ~/ 7) % Taste.values.length],
  );
}

/// 카페 불이 낮고 손님이 자는 시간.
bool cafeNight(DateTime t) => t.hour >= 21 || t.hour < 7;

/// 이 시간대에 카페에 와 있는 손님 둘이나 셋. 같은 시간대엔 같은 얼굴이고, 시간대가 바뀌면 바뀐다.
/// 시간대는 펫의 하루(새벽 5시 시작)를 여섯 시간씩 넷으로 나눈 것이다.
/// 잘 오는 요일인 애가 세 배 자주 나온다. 다른 날에도 올 수는 있어 놓치는 날은 없다.
/// 아는 강아지([known])는 시간대마다 반쯤 오고, [newcomers]는 꼭 온다. 남은 자리는 단골.
List<Guest> guestsAt(
  DateTime t, {
  List<Guest> known = const [],
  Set<String> newcomers = const {},
}) {
  // 시간대가 펫의 날 경계(새벽 5시)에 걸치면 '오늘 처음 만난 애'가 시간대 한가운데에서 바뀌어
  // 같은 시간대에 다시 갔을 때 얼굴이 달라진다.
  final day = petDate(t);
  final slot = ((t.hour - dayStartHour) % 24) ~/ 6;
  final seed = (day.year * 400 + day.month * 31 + day.day) * 4 + slot;
  final r = Random(seed);
  final pool = [...cafeRegulars];
  final n = 2 + r.nextInt(2);
  // 아는 강아지는 단골 뽑기와 다른 씨앗으로 정한다. 그래야 데려온 수와 상관없이 단골 순서가 그대로다.
  final picked = <Guest>[
    ...[
      for (final g in known)
        if (newcomers.contains(g.id)) g,
      for (final g in known)
        if (!newcomers.contains(g.id) &&
            Random(seed * 7919 + stableHash(g.id)).nextDouble() < knownChance)
          g,
    ].take(min(maxKnownSeats, n)),
  ];
  while (picked.length < n && pool.isNotEmpty) {
    final weights = [
      for (final g in pool) g.days.contains(day.weekday) ? 3.0 : 1.0,
    ];
    var roll = r.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    var i = 0;
    for (; i < pool.length - 1; i++) {
      roll -= weights[i];
      if (roll < 0) break;
    }
    picked.add(pool.removeAt(i));
  }
  return picked;
}

/// 쿠션 자리(화면 가로 비율). 손님 수에 맞춰 벌려 놓아 서로 겹치지 않는다.
List<double> seatsFor(int n) => switch (n) {
  >= 3 => const [0.18, 0.5, 0.82],
  2 => const [0.3, 0.7],
  _ => const [0.5],
};

/// 펫이 카페 바닥에서 할 다음 동작. 잠·밥·문 앞 기다리기는 집에서만 한다.
PetStep cafeStep(Random r) => switch (r.nextDouble()) {
  < 0.3 => PetStep(Behavior.walk, 6, targetX: 0.1 + r.nextDouble() * 0.8),
  < 0.55 => PetStep(Behavior.sit, 4 + r.nextDouble() * 4),
  < 0.72 => const PetStep(Behavior.sniff, 2.5),
  _ => PetStep(Behavior.idle, 3 + r.nextDouble() * 3),
};

/// 손님의 간단한 마음. 제 자리에서 앉고, 둘러보고, 킁킁대고, 가끔 존다. 밤엔 거의 잔다.
/// [roam]이 있으면(유치원 친구) 제 자리 둘레를 뛰어다니고 신나 한다. 주인 펫과 달리 배고픔·기분이 없다.
class GuestMind {
  GuestMind(this._random, {required this.seat, this.roam = 0}) : x = seat;

  final Random _random;

  /// 제 자리(화면 가로 비율). 카페에선 쿠션, 유치원에선 노는 자리의 가운데.
  final double seat;
  final double roam;

  /// 지금 서 있는 곳. 돌아다니지 않으면 늘 [seat]이다.
  double x;
  PetStep step = const PetStep(Behavior.sit, 4);
  double _remaining = 4;

  final List<PetStep> _queued = [];

  /// 펫이 해낸 개인기를 따라 한다. 차례로 하고, 끝나면 평소대로.
  void act(List<PetStep> steps) {
    if (steps.isEmpty) return;
    _queued
      ..clear()
      ..addAll(steps.skip(1));
    step = steps.first;
    _remaining = step.seconds;
  }

  void tick(double dt, {required bool night}) {
    _remaining -= dt;
    if (_remaining > 0) return;
    if (_queued.isNotEmpty) {
      step = _queued.removeAt(0);
      _remaining = step.seconds;
      return;
    }
    next(night: night);
  }

  /// 걷기·뛰기 목적지에 닿았다. 시킨 동작이 남았으면 이어서 한다(간식 받으러 와서 먹기).
  void arrived({required bool night}) {
    if (_queued.isNotEmpty) {
      step = _queued.removeAt(0);
      _remaining = step.seconds;
      return;
    }
    next(night: night);
  }

  void next({required bool night}) {
    final roll = _random.nextDouble();
    if (roam > 0 && !night) {
      double target() =>
          (seat - roam + _random.nextDouble() * roam * 2).clamp(0.08, 0.92);
      step = switch (roll) {
        < 0.25 => PetStep(Behavior.run, 4, targetX: target()),
        < 0.45 => PetStep(Behavior.walk, 5, targetX: target()),
        < 0.6 => const PetStep(Behavior.happy, 2),
        < 0.75 => const PetStep(Behavior.sniff, 2),
        _ => PetStep(Behavior.sit, 3 + _random.nextDouble() * 3),
      };
      _remaining = step.seconds;
      return;
    }
    if (night) {
      // 자다가 잠깐 고개만 든다.
      step = roll < 0.85
          ? PetStep(Behavior.sleep, 12 + _random.nextDouble() * 10)
          : PetStep(Behavior.idle, 2 + _random.nextDouble() * 2);
    } else {
      step = switch (roll) {
        < 0.12 => PetStep(Behavior.sleep, 10 + _random.nextDouble() * 10),
        < 0.45 => PetStep(Behavior.sit, 4 + _random.nextDouble() * 5),
        < 0.65 => const PetStep(Behavior.sniff, 2),
        _ => PetStep(Behavior.idle, 3 + _random.nextDouble() * 3),
      };
    }
    _remaining = step.seconds;
  }
}
