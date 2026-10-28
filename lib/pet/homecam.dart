import 'dart:math';

import 'pet_rules.dart';

/// 홈캠에 찍힌 장면 종류. 배고팠다·외로웠다 같은 건 없다(비운 걸 탓하는 장치가 되지 않게).
enum CamKind { doorOut, window, nap, toy, sniff, doorWait }

/// 주인이 없는 동안의 한 장면. 홈캠 다시보기에서 방 안 그 자리에 펫이 그 동작으로 보인다.
class CamMoment {
  const CamMoment(this.at, this.kind, this.x, {this.item});

  final DateTime at;
  final CamKind kind;

  /// 방 바닥 가로 위치(0~1).
  final double x;

  /// 가지고 논 물건 이름(toy일 때).
  final String? item;

  Behavior get behavior => switch (kind) {
    CamKind.doorOut || CamKind.doorWait => Behavior.waitAtDoor,
    CamKind.window => Behavior.watchWindow,
    CamKind.nap => Behavior.sleep,
    CamKind.toy => Behavior.happy,
    CamKind.sniff => Behavior.sniff,
  };

  String get label => switch (kind) {
    CamKind.doorOut => '나간 문 앞 서성임',
    CamKind.window => '창밖 구경',
    CamKind.nap => at.hour >= 21 || at.hour < 7 ? '쿨쿨 자는 중' : '낮잠',
    CamKind.toy => '$item 가지고 놀기',
    CamKind.sniff => '방 구석구석 킁킁',
    CamKind.doorWait => '문 앞에서 기다림',
  };
}

/// 홈캠은 두 시간 넘게 비웠을 때만 남는다.
const homeCamAfter = Duration(hours: 2);

/// 비운 사이([from]~[to])에 펫이 혼자 한 일 서너 장면. 리듬(잘 때)·성격·날씨·방에 둔 물건으로 정하고,
/// 같은 사이엔 늘 같은 장면이다. 장면은 20분 넘게 떨어져 있고 시간 순서다.
/// 밤잠은 [sleepX](친밀도에 따른 자는 자리)에서, 낮잠은 방석에서 잔다.
List<CamMoment> homeCamMoments({
  required DateTime from,
  required DateTime to,
  required bool Function(DateTime) asleepAt,
  required Traits traits,
  required int seed,
  bool ownerLeft = true,
  bool rainy = false,
  String? toyName,
  double? toyX,
  double sleepX = rugX,
}) {
  final span = to.difference(from);
  if (span < homeCamAfter) return const [];
  final r = Random(seed * 7919 + from.millisecondsSinceEpoch ~/ 60000);
  DateTime at(double fraction) =>
      from.add(Duration(minutes: (span.inMinutes * fraction).round()));
  final picks = <CamMoment>[];

  final out = from.add(Duration(minutes: 5 + r.nextInt(15)));
  if (ownerLeft && traits.attachment >= 0.35 && !asleepAt(out)) {
    picks.add(CamMoment(out, CamKind.doorOut, doorX));
  }

  // 잠: 비운 사이에 잘 시간이 있으면 그 첫 무렵, 없으면 덜 활발한 애는 긴 오후에 낮잠.
  DateTime? sleep;
  var night = false;
  for (
    var t = from.add(const Duration(minutes: 30));
    t.isBefore(to);
    t = t.add(const Duration(minutes: 10))
  ) {
    if (asleepAt(t)) {
      sleep = t;
      night = true;
      break;
    }
  }
  if (sleep == null &&
      traits.activity < 0.6 &&
      span >= const Duration(hours: 4)) {
    sleep = at(0.35 + r.nextDouble() * 0.2);
  }
  if (sleep != null) {
    picks.add(CamMoment(sleep, CamKind.nap, night ? sleepX : rugX));
  }

  // 나감·기다림 몫인 처음과 끝 30분을 뺀 깨어 있던 10분 칸. 잘 시간이 길어 깨어 있던 때가 짧아도 여기서 고른다.
  final awakeSlots = [
    for (
      var t = from.add(const Duration(minutes: 30));
      t.isBefore(to.subtract(const Duration(minutes: 30)));
      t = t.add(const Duration(minutes: 10))
    )
      if (!asleepAt(t)) t,
  ];
  DateTime? awake() =>
      awakeSlots.isEmpty ? null : awakeSlots[r.nextInt(awakeSlots.length)];

  if (rainy || r.nextDouble() < 0.6) {
    if (awake() case final t?) {
      picks.add(CamMoment(t, CamKind.window, windowX));
    }
  }
  if (awake() case final t?) {
    picks.add(
      toyName != null && toyX != null
          ? CamMoment(t, CamKind.toy, toyX, item: toyName)
          : CamMoment(t, CamKind.sniff, 0.25 + r.nextDouble() * 0.5),
    );
  }

  final back = to.subtract(Duration(minutes: 15 + r.nextInt(25)));
  if (traits.attachment >= 0.5 && !asleepAt(back)) {
    picks.add(CamMoment(back, CamKind.doorWait, doorX));
  }

  picks.sort((a, b) => a.at.compareTo(b.at));
  final kept = <CamMoment>[];
  for (final m in picks) {
    if (kept.isEmpty ||
        m.at.difference(kept.last.at) >= const Duration(minutes: 20)) {
      kept.add(m);
    }
  }
  // 넷이 넘으면 처음(나감)과 끝(기다림)을 두고 가운데를 줄인다.
  while (kept.length > 4) {
    kept.removeAt(kept.length ~/ 2);
  }
  return kept;
}

/// 일기에 남길 장면 하나. 기다림 > 창밖 > 놀기 > 잠 > 나감 순서로 크게 본다.
CamMoment? homeCamHighlight(List<CamMoment> moments) {
  const order = [
    CamKind.doorWait,
    CamKind.window,
    CamKind.toy,
    CamKind.nap,
    CamKind.sniff,
    CamKind.doorOut,
  ];
  for (final k in order) {
    for (final m in moments) {
      if (m.kind == k) return m;
    }
  }
  return null;
}
