import 'dart:math';

import 'guest.dart';
import 'pet_rules.dart';
import 'tricks.dart';

/// 유치원은 아침 7시에 열고 저녁 7시에 하원한다. 맡기는 건 오후 5시까지.
const kinderOpenHour = 7;
const kinderLastDropHour = 17;
const kinderCloseHour = 19;

bool kinderOpen(DateTime t) =>
    t.hour >= kinderOpenHour && t.hour < kinderCloseHour;

bool canDropOff(DateTime t) =>
    t.hour >= kinderOpenHour && t.hour < kinderLastDropHour;

/// 맡긴 날 저녁 하원 시각.
DateTime pickupAt(DateTime dropped) =>
    DateTime(dropped.year, dropped.month, dropped.day, kinderCloseHour);

/// 맡겨 둔 상태가 아직 이어지는지. 하원 시각이 지났거나 시계가 맡긴 때보다 앞으로 돌아갔으면 끝난 것으로 본다.
/// 시계를 되돌렸다고 펫이 며칠씩 유치원에 갇히면 안 된다.
bool inDaycareAt(DateTime dropped, DateTime now) =>
    !now.isBefore(dropped) && now.isBefore(pickupAt(dropped));

/// 다 같이 낮잠 자는 시간.
bool kinderNap(DateTime t) => t.hour == 13;

/// 유치원 친구들. 아기 그림에 색만 바꾼다.
const kinderFriends = [
  Guest(
    id: 'kong',
    look: '눈 동그란 하얀 아기',
    shape: 'maltese',
    puppy: true,
    main: 0xFFFFFBF2,
    second: 0xFFF6EBDD,
    marking: 0xFFFFFBF2,
    accent: 0xFF7EC8E3,
  ),
  Guest(
    id: 'bami',
    look: '귀 쫑긋한 밤색 아기',
    shape: 'shiba',
    puppy: true,
    main: 0xFFC98A4B,
    second: 0xFFFFF3DF,
    marking: 0xFF8A5530,
    accent: 0xFFE8A0B4,
  ),
  Guest(
    id: 'duri',
    look: '등 까만 아기',
    shape: 'corgi',
    puppy: true,
    main: 0xFF3B2F2A,
    second: 0xFFF7EEDF,
    marking: 0xFFB8743A,
    accent: 0xFFF2C14E,
  ),
  Guest(
    id: 'hodu',
    look: '코 납작한 까만 아기',
    shape: 'pug',
    puppy: true,
    main: 0xFF4A423D,
    second: 0xFF5C534D,
    marking: 0xFF1E1A18,
    accent: 0xFFD64040,
  ),
  Guest(
    id: 'mandu',
    look: '털 폭신한 노란 아기',
    shape: 'retriever',
    puppy: true,
    main: 0xFFF1D29A,
    second: 0xFFFBEBCB,
    marking: 0xFFF1D29A,
    accent: 0xFF6AAF5E,
  ),
];

/// 그날 유치원에 온 친구 셋. 같은 날엔 같은 얼굴이다.
List<Guest> friendsOn(DateTime t) {
  final r = Random((t.year * 400 + t.month * 31 + t.day) * 7 + 3);
  return ([...kinderFriends]..shuffle(r)).take(3).toList();
}

/// 펫이 유치원에서 할 다음 동작. 카페보다 많이 뛰고, 낮잠 시간엔 잔다.
PetStep kinderStep(Random r, DateTime now) {
  if (kinderNap(now)) return PetStep(Behavior.sleep, 20 + r.nextDouble() * 10);
  return switch (r.nextDouble()) {
    < 0.3 => PetStep(Behavior.run, 4, targetX: 0.1 + r.nextDouble() * 0.8),
    < 0.5 => PetStep(Behavior.walk, 5, targetX: 0.1 + r.nextDouble() * 0.8),
    < 0.65 => const PetStep(Behavior.happy, 2),
    < 0.8 => const PetStep(Behavior.sniff, 2.5),
    _ => PetStep(Behavior.sit, 3 + r.nextDouble() * 3),
  };
}

/// 유치원에서 보낸 시간만큼의 상태 변화. 친구들과 뛰어놀아 기분은 오르고 기운은 빠진다.
/// 간식을 조금씩 먹고 낮 12시에 점심을 먹는다. 1시엔 다 같이 잔다. 주인을 기다리지 않아 외롭지 않다.
PetStats applyDaycare(PetStats s, DateTime from, DateTime to) {
  const step = Duration(minutes: 10);
  if (!to.isAfter(from)) return s;
  var t = from;
  var mood = s.mood, hunger = s.hunger, energy = s.energy;
  while (t.isBefore(to)) {
    final next = t.add(step).isAfter(to) ? to : t.add(step);
    final hours = next.difference(t).inSeconds / 3600;
    hunger = min(100, hunger + 3 * hours);
    final lunch = DateTime(t.year, t.month, t.day, 12);
    if (!t.isAfter(lunch) && next.isAfter(lunch)) hunger = min(hunger, 15);
    energy = kinderNap(t)
        ? min(100, energy + 15 * hours)
        : max(5, energy - 5 * hours);
    if (mood < 85) mood = min(85, mood + 6 * hours);
    t = next;
  }
  return s.copyWith(mood: mood, hunger: hunger, energy: energy);
}

/// 비운 사이를 유치원에 있던 몫과 집에 있던 몫으로 나눠 계산한다. [dropped]가 없으면 집 규칙만.
PetStats elapsedWithDaycare(
  PetStats s,
  DateTime from,
  DateTime to, {
  DateTime? dropped,
  bool napping = false,
  bool Function(DateTime)? asleepAt,
  double sleepGain = 12,
}) {
  final until = dropped == null ? null : pickupAt(dropped);
  if (until == null || !until.isAfter(from) || !to.isAfter(from)) {
    return applyElapsed(
      s,
      from,
      to,
      napping: napping,
      asleepAt: asleepAt,
      sleepGain: sleepGain,
    );
  }
  final atKinder = applyDaycare(s, from, to.isBefore(until) ? to : until);
  if (!to.isAfter(until)) return atKinder;
  return applyElapsed(
    atKinder,
    until,
    to,
    asleepAt: asleepAt,
    sleepGain: sleepGain,
  );
}

/// 유치원 수업에서 연습할 개인기. 아직 못 배운 것 중 가장 많이 해낸 것. 다 배웠으면 null.
Trick? lessonTrick(Map<Trick, TrickProgress> tricks) {
  Trick? best;
  var most = -1;
  for (final t in Trick.values) {
    if (!t.chip) continue;
    final p = tricks[t] ?? const TrickProgress();
    if (p.learned || p.successes <= most) continue;
    best = t;
    most = p.successes;
  }
  return best;
}

/// 수업은 두 시간 넘게 있었던 날에만 한다. 잠깐 맡겼다 찾는 걸로 개인기를 쌓지 않게.
const lessonAfter = Duration(hours: 2);
