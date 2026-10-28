import 'dart:math';

import 'kindergarten.dart';
import 'tricks.dart';

/// 유치원 오늘의 한 장(아이디어 C2). 하원 때 그날 머문 동안 있었던 장면 하나를 고른다.
enum KinderScene { play, run, lunch, nap, lesson }

/// 이만큼은 있어야 한 장이 남는다.
const photoAfter = Duration(hours: 1);

/// 머문 동안 있을 수 있었던 장면들. 점심은 정오를 거쳐 있었을 때만(유치원 점심 계산과 같게),
/// 낮잠(1시)은 그 시간에 조금이라도 있었으면, 수업은 수업한 날만.
List<KinderScene> kinderScenes(
  DateTime from,
  DateTime to, {
  required bool lesson,
}) => [
  KinderScene.play,
  KinderScene.run,
  if (!from.isAfter(_at(from, 12)) && to.isAfter(_at(from, 12)))
    KinderScene.lunch,
  if (_covers(from, to, 13)) KinderScene.nap,
  if (lesson) KinderScene.lesson,
];

DateTime _at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

bool _covers(DateTime from, DateTime to, int hour) {
  final start = _at(from, hour);
  return from.isBefore(start.add(const Duration(hours: 1))) &&
      to.isAfter(start);
}

/// 오늘의 한 장: 장면 하나와 같이 찍힌 그날 친구 둘. 그날만 있는 장면(점심·낮잠·수업)이 두 배 잘 뽑힌다.
({KinderScene scene, List<String> friends})? planKinderPhoto(
  DateTime from,
  DateTime to, {
  required bool lesson,
  required Random random,
}) {
  if (to.difference(from) < photoAfter) return null;
  final bag = [
    for (final s in kinderScenes(from, to, lesson: lesson))
      ...List.filled(s == KinderScene.play || s == KinderScene.run ? 1 : 2, s),
  ];
  final pals = [...friendsOn(from)]..shuffle(random);
  return (
    scene: bag[random.nextInt(bag.length)],
    friends: [for (final g in pals.take(2)) g.id],
  );
}

String kinderCaption(KinderScene s, Trick? trick) => switch (s) {
  KinderScene.play => '친구들이랑 노는 중',
  KinderScene.run => '술래잡기',
  KinderScene.lunch => '점심 시간',
  KinderScene.nap => '낮잠 시간',
  KinderScene.lesson => trick == null ? '수업 시간' : "'${trick.label}' 수업",
};
