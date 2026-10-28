import 'dart:math';

import 'pet_rules.dart';

/// 모양 틀별 다 큰 몸무게(kg). 그 틀에 드는 견종들의 평균을 둥글게 잡았다.
const adultWeightKg = {
  'papillon': 3.5,
  'maltese': 3.2,
  'shiba': 9.0,
  'retriever': 28.0,
  'corgi': 12.0,
  'pug': 8.0,
  'noeul': 3.5,
};

/// 지금 몸무게(소수 한 자리). 아기는 다 클 수 있는 날(growDays)까지 다 큰 몸무게의 35%에서 75%로 크고,
/// 다 크면 그대로다. 펫마다 ±5% 다르게 펫 번호로 정한다.
double weightKg(
  String shape,
  PetStage stage,
  DateTime bornAt,
  DateTime now,
  int seed,
) {
  final base = adultWeightKg[shape] ?? 5.0;
  final days = max(0, now.difference(bornAt).inHours / 24);
  final growth = stage == PetStage.adult
      ? 1.0
      : 0.35 + 0.4 * min(days / growDays, 1);
  final own = 0.95 + Random(seed).nextDouble() * 0.1;
  return (base * growth * own * 10).round() / 10;
}

/// 체중계가 놓인 바닥 자리(0~1).
const scaleX = 0.5;

/// 병원에서 펫이 할 다음 동작. 낯선 냄새에 입구 쪽에서 머뭇거린다.
PetStep hospitalStep(Random r) => switch (r.nextDouble()) {
  < 0.5 => PetStep(Behavior.sit, 3 + r.nextDouble() * 3),
  < 0.75 => const PetStep(Behavior.sniff, 2),
  _ => PetStep(Behavior.walk, 4, targetX: 0.15 + r.nextDouble() * 0.2),
};

/// 검진은 일주일에 한 번. 하루 시작(새벽 5시) 기준으로 센다.
const checkupEvery = 7;

int daysUntilCheckup(DateTime? last, DateTime now) {
  if (last == null) return 0;
  final gap = petDate(now).difference(petDate(last)).inDays;
  // 시계를 되돌려 앞날이 되면 바로 받을 수 있게 한다.
  if (gap < 0) return 0;
  return max(0, checkupEvery - gap);
}

/// 건강 수첩 한 장. 사람 말 없이 숫자와 짧은 결과만 담는다.
class CheckupRecord {
  const CheckupRecord({
    required this.at,
    required this.weight,
    required this.previousWeight,
    required this.temperature,
    required this.shots,
    required this.puppy,
  });

  final DateTime at;
  final double weight;
  final double? previousWeight;

  /// 체온(℃). 늘 건강한 범위 안이다(아픈 일은 없다).
  final double temperature;

  /// 아기 때 맞은 접종 차수(최대 3). 성체는 다 맞은 것으로 본다.
  final int shots;
  final bool puppy;

  String get shotLabel => puppy ? '$shots/3차' : '완료';

  /// 지난번과 비교(첫 검진이면 null). +0.2kg처럼.
  String? get change {
    final p = previousWeight;
    if (p == null) return null;
    final d = ((weight - p) * 10).round() / 10;
    if (d == 0) return '그대로';
    return '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}kg';
  }
}

CheckupRecord checkupFor({
  required String shape,
  required PetStage stage,
  required DateTime bornAt,
  required DateTime now,
  required int seed,
  required int checkupsBefore,
  double? previousWeight,
}) {
  final puppy = stage == PetStage.puppy;
  final r = Random(seed * 31 + now.year * 400 + now.month * 31 + now.day);
  return CheckupRecord(
    at: now,
    weight: weightKg(shape, stage, bornAt, now, seed),
    previousWeight: previousWeight,
    temperature: ((38.2 + r.nextDouble() * 0.6) * 10).round() / 10,
    shots: puppy ? min(checkupsBefore + 1, 3) : 3,
    puppy: puppy,
  );
}
