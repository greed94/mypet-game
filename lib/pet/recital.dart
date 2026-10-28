import 'cues.dart';
import 'pet_rules.dart';
import 'tricks.dart';

/// 유치원 발표회 요일(기본값). 펫의 하루로 센다.
const recitalWeekday = DateTime.friday;

/// 발표회에서 잇달아 보여 줄 개인기 수(기본값).
const recitalSize = 3;

bool recitalDay(DateTime t) => petDate(t).weekday == recitalWeekday;

/// 발표회 날 맡겨 두면 오후 3시(낮잠 뒤)에 유치원에서 발표회를 한다.
const daycareRecitalHour = 15;

/// CCTV로 보고 있으면 이 안에 시작한다. 지나서 열면 하원할 때 하고 온 것으로 친다.
const daycareRecitalWindow = Duration(minutes: 10);

String recitalStatsTo(PetStats s) =>
    '${s.mood},${s.hunger},${s.energy},${s.affection}';

PetStats? parseRecitalStats(String? saved) {
  final values = saved?.split(',').map(double.tryParse).toList();
  if (values == null ||
      values.length != 4 ||
      values.any((v) => v == null || !v.isFinite || v < 0 || v > 100)) {
    return null;
  }
  return PetStats(
    mood: values[0]!,
    hunger: values[1]!,
    energy: values[2]!,
    affection: values[3]!,
  );
}

DateTime daycareRecitalAt(DateTime dropped) =>
    DateTime(dropped.year, dropped.month, dropped.day, daycareRecitalHour);

/// 맡긴 동안 발표회 시각이 지났는지(발표회 날 3시 전에 맡겼고 [at]이 3시를 넘었다).
bool daycareRecitalHeld(DateTime dropped, DateTime at) =>
    recitalDay(dropped) &&
    dropped.isBefore(daycareRecitalAt(dropped)) &&
    !at.isBefore(daycareRecitalAt(dropped));

/// 도장 받은 날들. DB에는 dayKey를 쉼표로 이어 둔다.
List<String> parseStamps(String? csv) =>
    csv == null || csv.isEmpty ? const [] : csv.split(',');

/// 발표회에서 보여 줄 개인기. 배운 것 중 별이 많은 순, 같으면 많이 해낸 순, 그다음 칩 순서.
/// '물어와'는 유치원에 공이 없어 뺀다.
List<Trick> recitalSet(Map<Trick, TrickProgress> tricks) {
  final learned = [
    for (final t in Trick.values)
      if (t.chip && t != Trick.fetch && (tricks[t]?.learned ?? false)) t,
  ];
  learned.sort((a, b) {
    final pa = tricks[a]!, pb = tricks[b]!;
    if (pa.stars != pb.stars) return pb.stars - pa.stars;
    if (pa.successes != pb.successes) return pb.successes - pa.successes;
    return a.index - b.index;
  });
  return learned.take(recitalSize).toList();
}

/// 발표회 차례. 무대(가운데)로 나가 개인기를 잇달아 하고 마지막에 도장을 받는다(StepTag.stamp).
/// 못 한 개인기는 갸웃하고 넘어간다. 도장은 다 해내지 못해도 받는다.
List<PetStep> recitalSteps(List<(Trick, bool)> acts) => [
  const PetStep(Behavior.walk, 8, targetX: 0.5, thought: '오늘은 발표회!'),
  const PetStep(Behavior.sit, 1.2, cue: Cue.whine),
  for (final (t, ok) in acts) ...[
    if (ok)
      ...trickSteps(t)
    else
      const PetStep(Behavior.idle, 1.6, cue: Cue.whine, thought: '어… 뭐였더라?'),
    const PetStep(Behavior.idle, 0.6),
  ],
  const PetStep(
    Behavior.happy,
    2.5,
    cue: Cue.chime,
    thought: '도장 받았다!',
    tag: StepTag.stamp,
  ),
];
