import 'dart:convert';
import 'dart:math';

import 'pet_rules.dart';

/// 주인이 앱을 여는 때를 배워 강아지 하루를 맞춘다.
/// 앱은 주인이 실제로 언제 일어나고 자는지 모르고, 언제 앱을 여는지만 안다.
class OwnerRhythm {
  const OwnerRhythm({
    this.opens = const [],
    this.todaySlots = const [],
    this.bedtime,
    this.wakeUp,
    this.nights = 0,
    this.days = 0,
    this.lastDay,
    this.goodnightAt,
  });

  /// 30분 칸 48개. 그 시각에 앱을 연 날이 많을수록 크다. 날마다 조금씩 흐려진다.
  final List<double> opens;

  /// 오늘 이미 센 칸. 같은 날 같은 칸에서 여러 번 열어도 한 번으로 친다.
  final List<int> todaySlots;

  /// 정오부터 센 분(23시 = 660, 새벽 1시 = 780). 자정을 넘나드는 값을 평균 내기 쉽게.
  final int? bedtime;

  /// 자정부터 센 분.
  final int? wakeUp;

  /// 잠자리·기상 시각을 배운 밤 수.
  final int nights;

  /// 앱을 연 서로 다른 날 수.
  final int days;
  final String? lastDay;

  /// 저녁 이후에 마지막으로 잘 자라고 한 때. 그 밤은 이때부터 잔다.
  final DateTime? goodnightAt;

  static const _slots = 48;
  static const _fade = 0.85;

  /// 이만큼 배우기 전에는 기본 리듬(23시~7시)을 쓴다.
  static const learnDays = 3;

  /// 앱을 열었다. 저녁에 닫고 5시간 넘게 지나 아침에 열었으면 그 사이 잠들었다가 일어난 것으로 본다.
  /// 잠자리 시각은 마지막으로 앱을 닫은 때다. 잘 자라고 해 놓고 더 쓰다 닫았으면 닫은 때가 맞다.
  OwnerRhythm observeOpen(DateTime now, DateTime? previous) {
    final day = petDate(now);
    final today = dayKey(day);
    final newDay = lastDay != today;
    final fade = newDay ? pow(_fade, _daysSince(day)).toDouble() : 1.0;
    final bins = List<double>.generate(
      _slots,
      (i) => (i < opens.length ? opens[i] : 0.0) * fade,
    );
    final counted = newDay ? <int>[] : [...todaySlots];
    final slot = _slot(now);
    if (!counted.contains(slot)) {
      bins[slot] += 1;
      counted.add(slot);
    }
    var bed = bedtime, wake = wakeUp, seen = nights;
    if (previous != null && now.difference(previous).inHours >= 5) {
      final p = _sinceNoon(previous);
      final w = now.hour * 60 + now.minute;
      // 점심에 연 것처럼 밤을 건너지 않은 공백은 잠으로 세지 않는다.
      if (_evening(p) && w >= 240 && w <= 780) {
        final young = nights < learnDays;
        bed = _follow(bed, p, fastUp: true, young: young);
        wake = _follow(wake, w, fastUp: false, young: young);
        seen++;
      }
    }
    return OwnerRhythm(
      opens: bins,
      todaySlots: counted,
      bedtime: bed,
      wakeUp: wake,
      nights: seen,
      days: newDay ? days + 1 : days,
      lastDay: today,
      goodnightAt: goodnightAt,
    );
  }

  /// 잘 자라고 했다. 그 밤은 이때부터 잔다. 낮에 한 말은 낮잠이라 세지 않는다.
  OwnerRhythm observeGoodnight(DateTime now) {
    if (!_evening(_sinceNoon(now))) return this;
    return OwnerRhythm(
      opens: opens,
      todaySlots: todaySlots,
      bedtime: bedtime,
      wakeUp: wakeUp,
      nights: nights,
      days: days,
      lastDay: lastDay,
      goodnightAt: now,
    );
  }

  bool get learned => days >= learnDays;

  /// 강아지가 자는 때. 잘 자라고 하면 바로 자고, 안 하면 배운 밤에 잔다.
  bool isDogNight(DateTime t) {
    final m = _sinceNoon(t);
    final g = goodnightAt;
    // 잘 자라고 한 그 밤에만. 정오를 넘기면 정오부터 센 분이 다시 작아지니 그 전으로 막는다.
    if (g != null &&
        !t.isBefore(g) &&
        t.difference(g).inHours < 12 &&
        m >= _sinceNoon(g) &&
        m < _wakeEnd) {
      return true;
    }
    final n = _night;
    if (n == null) return isNight(t);
    return m >= n.start && m < n.end;
  }

  /// 곧 잘 시간이라 졸린 때(잠들기 전 한 시간 반).
  bool isDrowsy(DateTime t) {
    if (isDogNight(t)) return false;
    final m = _sinceNoon(t);
    final start = _night?.start ?? 660;
    return m >= start - 90 && m < start;
  }

  /// 잘 때 시간당 차는 기운. 밤이 기본(8시간)보다 짧으면 그만큼 깊게 자서 밤잠 한 번에 같은 만큼 찬다.
  /// 밤이 짧은 주인의 강아지가 날마다 지쳐 가지 않게.
  double get sleepGain {
    final n = _night;
    final minutes = n == null ? 480 : n.end - n.start;
    return 12 * max(1.0, 480 / minutes);
  }

  /// 배운 강아지의 밤(정오부터 센 분). 주인이 보통 자러 가는 때보다 한 시간까지 기다렸다가 자고,
  /// 보통 일어나는 때보다 40분 먼저 깬다. 네 시간은 자야 해서 밤이 짧은 주인이면 그만큼 일찍 잔다.
  /// 아직 못 배웠으면 null이고 기본 밤(23~7시)을 쓴다.
  ({int start, int end})? get _night {
    final bed = bedtime;
    if (!learned || bed == null || wakeUp == null) return null;
    final end = _wakeEnd;
    return (start: min(bed + 60, end - 240), end: end);
  }

  /// 정오 기준 분은 정오에 다시 0이 되므로, 정오 넘어 일어나는 주인이어도 강아지는 늦어도 정오에 깬다.
  int get _wakeEnd => min((wakeUp ?? 420) + 680, 1440);

  /// 주인이 보통 이맘때 여는지(0~1). 사흘쯤 같은 때 열면 1에 가깝다.
  double usualAt(DateTime t) {
    if (opens.isEmpty) return 0;
    final s = _slot(t);
    double at(int i) => opens[(i + _slots) % _slots];
    final w = at(s) + (at(s - 1) + at(s + 1)) * 0.5;
    return (w / 2.5).clamp(0.0, 1.0);
  }

  /// 마지막으로 연 날부터 [day]까지 지난 날 수. 시계를 되돌렸거나 값이 이상하면 하루로 친다.
  int _daysSince(DateTime day) {
    final last = DateTime.tryParse(lastDay ?? '');
    if (last == null) return 1;
    return max(1, (day.difference(last).inHours / 24).round());
  }

  static int _slot(DateTime t) => (t.hour * 60 + t.minute) ~/ 30;

  static int _sinceNoon(DateTime t) =>
      ((t.hour * 60 + t.minute) - 720 + 1440) % 1440;

  /// 18시~새벽 5시.
  static bool _evening(int sinceNoon) => sinceNoon >= 360 && sinceNoon <= 1020;

  /// 처음 몇 밤은 가장 늦게 닫은 때와 가장 일찍 연 때를 쓴다. 첫날 저녁 일찍 닫은 것 하나로 잠자리가
  /// 정해지지 않게. 그 뒤로는 비율로 따라간다. 주인을 놓치지 않는 쪽(더 늦게 자기, 더 일찍 일어나기)으로는
  /// 빨리, 반대쪽으로는 천천히 가고, 반대쪽으로 두 시간 넘게 다른 날(주말 늦잠 같은)은 반만 친다.
  static int _follow(
    int? old,
    int x, {
    required bool fastUp,
    required bool young,
  }) {
    if (old == null) return x;
    if (young) return fastUp ? max(old, x) : min(old, x);
    final fast = x > old == fastUp;
    var rate = fast ? 0.5 : 0.15;
    if (!fast && (x - old).abs() > 120) rate /= 2;
    return (old + (x - old) * rate).round();
  }

  String toJson() => jsonEncode({
    'opens': [for (final v in opens) double.parse(v.toStringAsFixed(3))],
    'todaySlots': todaySlots,
    'bedtime': bedtime,
    'wakeUp': wakeUp,
    'nights': nights,
    'days': days,
    'lastDay': lastDay,
    'goodnightAt': goodnightAt?.toIso8601String(),
  });

  /// 저장된 값이 깨져 있으면 처음부터 다시 배운다.
  static OwnerRhythm fromJson(String? s) {
    if (s == null || s.isEmpty) return const OwnerRhythm();
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final opens = [
        for (final v in (m['opens'] as List? ?? [])) (v as num).toDouble(),
      ];
      // 칸 수가 다르면(깨졌거나 칸 나누기를 바꾼 뒤) 이맘때 여는지 물을 때 앱이 죽는다.
      if (opens.isNotEmpty && opens.length != _slots) {
        return const OwnerRhythm();
      }
      final g = m['goodnightAt'] as String?;
      return OwnerRhythm(
        opens: opens,
        todaySlots: [
          for (final v in (m['todaySlots'] as List? ?? [])) v as int,
        ],
        bedtime: m['bedtime'] as int?,
        wakeUp: m['wakeUp'] as int?,
        nights: m['nights'] as int? ?? 0,
        days: m['days'] as int? ?? 0,
        lastDay: m['lastDay'] as String?,
        goodnightAt: g == null ? null : DateTime.tryParse(g),
      );
    } on FormatException {
      return const OwnerRhythm();
    } on TypeError {
      return const OwnerRhythm();
    }
  }
}
