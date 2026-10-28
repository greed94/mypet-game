import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/rhythm.dart';

/// 자정형 직장인: 07:50, 12:40, 20:30, 다음 날 00:30(10분)에 연다.
OwnerRhythm midnightWorker(int days) {
  var r = const OwnerRhythm();
  DateTime? last;
  void open(DateTime t, [int minutes = 1]) {
    r = r.observeOpen(t, last);
    last = t.add(Duration(minutes: minutes));
  }

  for (var i = 0; i < days; i++) {
    final d = DateTime(2026, 10, 5 + i);
    open(d.add(const Duration(hours: 7, minutes: 50)));
    open(d.add(const Duration(hours: 12, minutes: 40)));
    open(d.add(const Duration(hours: 20, minutes: 30)), 3);
    open(d.add(const Duration(days: 1, minutes: 30)), 10);
  }
  return r;
}

DateTime at(int day, int h, int m) => DateTime(2026, 10, day, h, m);

/// (여는 시각, 머문 분)을 차례로 연다.
OwnerRhythm live(List<(DateTime, int)> opens) {
  var r = const OwnerRhythm();
  DateTime? last;
  for (final (t, minutes) in opens) {
    r = r.observeOpen(t, last);
    last = t.add(Duration(minutes: minutes));
  }
  return r;
}

void main() {
  test('배우기 전에는 밤 23시~7시로 잔다', () {
    const r = OwnerRhythm();
    expect(r.isDogNight(at(5, 23, 30)), isTrue);
    expect(r.isDogNight(at(5, 22, 30)), isFalse);
    expect(r.isDogNight(at(6, 6, 50)), isTrue);
    expect(r.isDrowsy(at(5, 22, 0)), isTrue);
  });

  test('자정에 여는 주인이면 0시 반엔 졸려도 깨어 있고, 새벽에 자다가 주인보다 먼저 깬다', () {
    final r = midnightWorker(5);
    expect(r.learned, isTrue);
    expect(r.isDogNight(at(11, 0, 30)), isFalse);
    expect(r.isDrowsy(at(11, 0, 30)), isTrue);
    expect(r.isDogNight(at(11, 3, 0)), isTrue);
    expect(r.isDogNight(at(11, 7, 45)), isFalse);
    // 기본 리듬이었다면 이 시각엔 자고 있었다.
    expect(isNight(at(11, 0, 30)), isTrue);
  });

  test('점심에 연 건 일어난 시각으로 세지 않는다(아침형이 6시 반에 열면 깨어 있다)', () {
    var r = const OwnerRhythm();
    DateTime? last;
    for (var i = 0; i < 5; i++) {
      for (final (h, m) in [(6, 30), (12, 0), (21, 0), (22, 30)]) {
        final t = at(5 + i, h, m);
        r = r.observeOpen(t, last);
        last = t.add(const Duration(minutes: 2));
      }
      r = r.observeGoodnight(at(5 + i, 22, 32));
    }
    expect(r.wakeUp, closeTo(390, 5));
    expect(r.isDogNight(at(10, 6, 30)), isFalse);
    expect(r.isDogNight(at(9, 23, 0)), isTrue);
  });

  test('주말에 일찍 잤다고 평일 0시 반에 먼저 잠들어 있지 않는다', () {
    var r = midnightWorker(5);
    for (final day in [10, 11]) {
      r = r.observeGoodnight(at(day, 23, 50));
      r = r.observeOpen(at(day + 1, 10, 0), at(day, 23, 55));
    }
    expect(r.isDogNight(at(13, 0, 30)), isFalse);
  });

  test('잘 자라고 하면 그때부터 아침까지 자고, 낮에 한 잘 자는 낮잠이라 세지 않는다', () {
    final r = midnightWorker(5).observeGoodnight(at(11, 0, 10));
    expect(r.isDogNight(at(11, 0, 20)), isTrue);
    expect(r.isDogNight(at(11, 8, 0)), isFalse);
    expect(r.isDogNight(at(11, 11, 50)), isFalse);
    final nap = midnightWorker(5).observeGoodnight(at(10, 14, 0));
    expect(nap.goodnightAt, isNull);
    expect(nap.isDogNight(at(10, 14, 30)), isFalse);
  });

  test('자주 여는 시각을 안다. 같은 날 같은 칸은 한 번만 센다', () {
    final r = midnightWorker(4);
    expect(r.usualAt(at(9, 20, 35)), greaterThan(0.9));
    expect(r.usualAt(at(9, 15, 0)), 0);
    var once = const OwnerRhythm().observeOpen(at(5, 9, 0), null);
    for (var i = 1; i < 5; i++) {
      once = once.observeOpen(at(5, 9, i), null);
    }
    expect(once.usualAt(at(5, 9, 0)), closeTo(0.4, 0.01));
  });

  test('늦게 잔 날은 금방 따라가 더 기다리고, 일찍 잔 날은 천천히 따라간다', () {
    final base = midnightWorker(5);
    final bed = base.bedtime!;
    final late = base.observeOpen(at(11, 9, 0), at(11, 3, 30));
    expect(late.bedtime! - bed, greaterThan(20));
    final early = base.observeOpen(at(11, 9, 0), at(10, 23, 30));
    expect(bed - early.bedtime!, lessThan(15));
  });

  test('주말 늦잠에 끌려 월요일 아침 강아지가 자고 있지 않는다', () {
    var r = midnightWorker(5);
    for (final day in [10, 11]) {
      r = r.observeOpen(at(day, 10, 40), at(day, 0, 5));
    }
    expect(r.isDogNight(at(12, 7, 45)), isFalse);
  });

  test('저장했다가 다시 읽어도 같고, 깨진 값은 처음부터 배운다', () {
    final r = midnightWorker(3).observeGoodnight(at(8, 0, 5));
    final back = OwnerRhythm.fromJson(r.toJson());
    expect(back.bedtime, r.bedtime);
    expect(back.wakeUp, r.wakeUp);
    expect(back.days, r.days);
    expect(back.goodnightAt, r.goodnightAt);
    expect(
      back.usualAt(at(8, 20, 30)),
      closeTo(r.usualAt(at(8, 20, 30)), 0.01),
    );
    expect(back.nights, r.nights);
    expect(OwnerRhythm.fromJson('{"opens": "x"}').days, 0);
    expect(OwnerRhythm.fromJson('not json').days, 0);
    // 칸 수가 다르면 이맘때 여는지 물을 때 죽지 않게 처음부터 배운다.
    final odd = OwnerRhythm.fromJson('{"opens": [1, 2, 3], "days": 9}');
    expect(odd.days, 0);
    expect(odd.usualAt(at(8, 20, 30)), 0);
  });

  test('밤이 여섯 시간뿐인 주인이어도 강아지는 네 시간은 자고, 깊게 자서 저녁마다 지쳐 있지 않다', () {
    // 07:00 기상, 00:50에 열어 01:00에 잔다.
    final r = live([
      for (var d = 5; d < 11; d++) ...[
        (at(d, 7, 0), 1),
        (at(d, 12, 40), 1),
        (at(d, 20, 30), 3),
        (at(d + 1, 0, 50), 10),
      ],
    ]);
    expect(r.isDogNight(at(11, 0, 55)), isFalse);
    expect(r.isDogNight(at(11, 2, 30)), isTrue);
    expect(r.isDogNight(at(11, 6, 50)), isFalse);
    var s = const PetStats(mood: 65, hunger: 30, energy: 80, affection: 50);
    var t = at(11, 20, 30);
    for (var d = 0; d < 14; d++) {
      // 저녁마다 공놀이와 산책으로 기운을 쓴다.
      s = s.copyWith(energy: s.energy - 20);
      final next = t.add(const Duration(days: 1));
      s = applyElapsed(
        s,
        t,
        next,
        asleepAt: r.isDogNight,
        sleepGain: r.sleepGain,
      );
      t = next;
      expect(s.energy, greaterThan(tiredEnergy + 20));
    }
  });

  test('하룻밤 새벽까지 깨어 있어도 다음 밤 자정 무렵엔 깨어 있다', () {
    var r = midnightWorker(6).observeGoodnight(at(11, 4, 30));
    r = r.observeOpen(at(11, 11, 0), at(11, 4, 35));
    expect(r.isDogNight(at(11, 23, 30)), isFalse);
    expect(r.isDogNight(at(12, 0, 30)), isFalse);
    expect(r.isDogNight(at(12, 5, 0)), isTrue);
  });

  test('잘 자를 몇 번 해도 그 밤에 잘 뿐이고, 잠자리 시각은 앱을 닫은 때로 배운다', () {
    final base = midnightWorker(5);
    var r = base;
    for (var i = 0; i < 5; i++) {
      r = r.observeGoodnight(at(10, 21, i));
    }
    expect(r.bedtime, base.bedtime);
    expect(r.isDogNight(at(10, 21, 30)), isTrue);
    // 잘 자 하고도 평소처럼 00:40까지 쓰다 잤다.
    r = r.observeOpen(at(11, 7, 50), at(11, 0, 40));
    expect(r.bedtime, base.bedtime);
    expect(r.isDogNight(at(12, 0, 30)), isFalse);
  });

  test('첫날 저녁 일찍 닫은 것 하나로 잠자리가 정해지지 않는다', () {
    final r = live([
      (at(5, 8, 0), 1),
      (at(5, 18, 0), 30),
      for (var d = 6; d < 9; d++) ...[(at(d, 7, 0), 1), (at(d, 23, 0), 5)],
      (at(9, 7, 0), 1),
    ]);
    expect(r.learned, isTrue);
    expect(r.isDogNight(at(9, 21, 0)), isFalse);
    expect(r.isDogNight(at(9, 23, 30)), isFalse);
  });

  test('사흘을 열었어도 밤을 건너 연 적이 없으면 기본 밤(23~7시)에 잔다', () {
    final r = live([
      for (var d = 5; d < 9; d++) ...[(at(d, 10, 0), 1), (at(d, 15, 0), 1)],
    ]);
    expect(r.learned, isTrue);
    expect(r.bedtime, isNull);
    expect(r.isDogNight(at(8, 22, 30)), isFalse);
    expect(r.isDogNight(at(8, 23, 30)), isTrue);
    expect(r.isDogNight(at(9, 6, 40)), isTrue);
  });

  test('며칠 안 열면 그동안 흐려져서, 몇 주 뒤엔 예전 시각을 늘 오는 때로 치지 않는다', () {
    var r = midnightWorker(4);
    expect(r.usualAt(at(9, 20, 30)), greaterThan(0.9));
    r = r.observeOpen(at(25, 9, 0), at(9, 0, 40));
    expect(r.usualAt(at(25, 20, 30)), lessThan(0.2));
  });
}
