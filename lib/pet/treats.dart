import 'dart:math';

import 'cues.dart';
import 'pet_rules.dart';
import 'treasure.dart';

/// 간식 가게의 간식. 맛 갈래는 발견물 취향(Taste)과 같다. 동그란 물건을 좋아하는 애는 동그란 간식도 좋아한다.
class Treat {
  const Treat(this.id, this.name, this.taste, this.color);

  final String id;
  final String name;
  final Taste taste;

  /// 진열장·주머니에 그릴 색.
  final int color;
}

const treats = [
  Treat('cheese_ball', '치즈 볼', Taste.round, 0xFFF7D774),
  Treat('pumpkin_ball', '단호박 볼', Taste.round, 0xFFF2A65A),
  Treat('sweet_potato', '고구마 칩', Taste.rustle, 0xFFD98C5F),
  Treat('pollack', '황태 채', Taste.rustle, 0xFFE8D2A6),
  Treat('apple_jelly', '사과 젤리', Taste.shiny, 0xFFF08080),
  Treat('blueberry_jelly', '블루베리 젤리', Taste.shiny, 0xFF8C9EE0),
  Treat('jerky', '소고기 육포', Taste.smelly, 0xFFA0522D),
  Treat('chicken', '닭가슴살', Taste.smelly, 0xFFF3E1C7),
];

/// 먹여 본 간식과 반응. 저장은 'id:반응' 쉼표 목록.
Map<String, Reaction> parseTried(String? raw) => {
  for (final part in (raw ?? '').split(','))
    if (part.split(':') case [
      final id,
      final r,
    ] when treatById(id) != null && Reaction.values.asNameMap()[r] != null)
      id: Reaction.values.asNameMap()[r]!,
};

String? triedToCsv(Map<String, Reaction> tried) => tried.isEmpty
    ? null
    : [for (final e in tried.entries) '${e.key}:${e.value.name}'].join(',');

Treat? treatById(String id) {
  for (final t in treats) {
    if (t.id == id) return t;
  }
  return null;
}

/// 진열장 네 칸의 바닥 자리(0~1). 펫이 이 앞에 서서 냄새를 맡는다.
const shopSlots = [0.2, 0.4, 0.6, 0.8];

/// 그날 진열장에 놓인 간식 넷. 같은 날엔 같다.
List<Treat> lineupOn(DateTime day) {
  final r = Random((day.year * 400 + day.month * 31 + day.day) * 11 + 5);
  return ([...treats]..shuffle(r)).take(shopSlots.length).toList();
}

/// 펫이 고르는 칸. 좋아하는 갈래가 있으면 그것, 없으면 싫어하는 갈래가 아닌 첫 칸.
int pickIndex(List<Treat> lineup, Taste? like, Taste? dislike) {
  final liked = lineup.indexWhere((t) => t.taste == like);
  if (liked >= 0) return liked;
  final fine = lineup.indexWhere((t) => t.taste != dislike);
  return fine >= 0 ? fine : 0;
}

/// 진열장을 한 칸씩 킁킁대며 돌고, 고른 칸 앞에 앉는다.
List<PetStep> sniffTour(int pick) => [
  for (final x in shopSlots) ...[
    PetStep(Behavior.walk, 3, targetX: x),
    const PetStep(Behavior.sniff, 1.2, cue: Cue.sniff),
  ],
  ...toPick(pick),
];

/// 고른 칸으로 가서 앉는다. 앉는 순간부터 고른 간식이 보인다.
List<PetStep> toPick(int pick) => [
  PetStep(Behavior.walk, 3, targetX: shopSlots[pick]),
  const PetStep(Behavior.sit, 30, tag: StepTag.pick, thought: '이거!'),
];

/// 고른 뒤 가게에서 할 동작. 고른 칸 둘레를 맴돈다.
PetStep shopStep(Random r, double near) => switch (r.nextDouble()) {
  < 0.55 => PetStep(Behavior.sit, 4 + r.nextDouble() * 3),
  < 0.8 => const PetStep(Behavior.sniff, 2),
  _ => PetStep(
    Behavior.walk,
    3,
    targetX: (near - 0.1 + r.nextDouble() * 0.2).clamp(0.12, 0.88),
  ),
};

/// 주머니에 넣어 둘 수 있는 간식 수. 하루 하나씩 사니 사흘 치.
const pouchSize = 3;

List<String> pouchFrom(String? raw) => raw == null || raw.isEmpty
    ? []
    : [
        for (final id in raw.split(','))
          if (treatById(id) != null) id,
      ];

String? pouchTo(List<String> ids) => ids.isEmpty ? null : ids.join(',');

/// 오늘 간식을 산 뒤 발도장으로 하나 더 살 때의 값(기본값).
const extraTreatPaws = 3;

/// 오늘([today]) 간식을 나눠 준 친구들. 저장은 'dayKey|id,id'. 날이 바뀌면 비어 있다.
Set<String> sharedOn(String? raw, String today) {
  final parts = (raw ?? '').split('|');
  if (parts.length != 2 || parts[0] != today || parts[1].isEmpty) return {};
  return parts[1].split(',').toSet();
}

String sharesTo(String today, Set<String> ids) => '$today|${ids.join(',')}';

/// 간식을 먹은 반응. 좋아하는 갈래면 크게 기뻐하고, 싫어하는 갈래면 냄새만 맡고 만다.
({PetStats stats, List<PetStep> steps, Reaction reaction}) eatTreat(
  PetStats s,
  Treat t,
  Taste? like,
  Taste? dislike,
) {
  if (t.taste == like) {
    return (
      stats: s.copyWith(mood: s.mood + 10, hunger: s.hunger - 8),
      steps: [
        const PetStep(Behavior.eat, 2, cue: Cue.crunch, tag: StepTag.snack),
        PetStep(Behavior.happy, 2.5, cue: Cue.bark, thought: '${t.name} 최고야!'),
      ],
      reaction: Reaction.love,
    );
  }
  if (t.taste == dislike) {
    return (
      stats: s.copyWith(mood: s.mood + 1, hunger: s.hunger - 2),
      steps: const [
        PetStep(Behavior.sniff, 2, cue: Cue.sniff, thought: '이건… 별로야.'),
        PetStep(Behavior.sit, 1.5),
      ],
      reaction: Reaction.meh,
    );
  }
  return (
    stats: s.copyWith(mood: s.mood + 5, hunger: s.hunger - 8),
    steps: const [
      PetStep(
        Behavior.eat,
        3,
        cue: Cue.crunch,
        thought: '냠냠.',
        tag: StepTag.snack,
      ),
    ],
    reaction: Reaction.plain,
  );
}
