import 'dart:math';

import 'cues.dart';
import 'guest.dart';
import 'pet_rules.dart';
import 'tricks.dart';

/// 친구 사이. 카페에서 만난 날마다 한 칸씩 가까워지고, 안 가도 멀어지지 않는다.
enum Bond { none, stranger, sniff, play, bestie }

String bondLabel(Bond b) => switch (b) {
  Bond.none => '아직',
  Bond.stranger => '낯섦',
  Bond.sniff => '킁킁',
  Bond.play => '놀이',
  Bond.bestie => '단짝',
};

class Friendship {
  const Friendship({
    this.bond = Bond.none,
    this.days = 0,
    this.lastDay,
    this.name,
    this.streak = 0,
  });

  final Bond bond;

  /// 만난 날 수.
  final int days;

  /// 마지막으로 만난 날(dayKey).
  final String? lastDay;

  /// 주인이 붙여 준 이름. 없으면 생김새로 부른다.
  final String? name;

  /// 마지막으로 만난 날까지 며칠 내리 만났는지. 사흘이면 그 애 버릇이 옮는다.
  final int streak;

  /// 오늘 만났다. 하루에 한 칸만 오른다. 어제도 만났으면 내리 만난 날이 하루 는다.
  Friendship met(String today) {
    if (lastDay == today) return this;
    final last = lastDay == null ? null : DateTime.tryParse(lastDay!);
    final yesterday =
        last != null && DateTime.parse(today).difference(last).inDays == 1;
    return Friendship(
      bond: Bond.values[min(bond.index + 1, Bond.bestie.index)],
      days: days + 1,
      lastDay: today,
      name: name,
      streak: yesterday ? streak + 1 : 1,
    );
  }

  Friendship named(String? n) => Friendship(
    bond: bond,
    days: days,
    lastDay: lastDay,
    name: n,
    streak: streak,
  );
}

/// 일기·카드에서 부르는 말. 이름이 없으면 생김새.
String friendName(Guest g, Friendship? f) => f?.name ?? g.look;

/// 주인이 붙이는 이름 다듬기. 빈 이름은 없음, 열 자까지.
String? cleanFriendName(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return null;
  // 글자(코드 포인트) 단위로 자른다. UTF-16 단위로 자르면 이모지 한가운데가 잘린다.
  return String.fromCharCodes(t.runes.take(10));
}

/// 그 애 옆에 서는 자리. 쿠션 안쪽(화면 가운데 쪽)으로 조금 떨어져서.
double besideGuest(double guestX) =>
    (guestX < 0.5 ? guestX + 0.16 : guestX - 0.16).clamp(0.1, 0.9);

/// 카페에 들어가 그 애와 하는 장면. 낯설 땐 멀찍이 앉아 보기만 한다.
/// 걷기는 닿으면 끝나니 길게 잡는다. 입구(화면 밖 왼쪽)에서 오른쪽 끝까지 가는 데 9초쯤 걸린다.
List<PetStep> meetSteps(
  Bond bond,
  double guestX,
  String name, {
  bool night = false,
}) {
  final near = besideGuest(guestX);
  // 밤엔 손님이 자고 있다. 깨우지 않고 옆에 가서 조용히 앉는다.
  if (night && bond.index >= Bond.sniff.index) {
    return [
      PetStep(Behavior.walk, 12, targetX: near),
      PetStep(
        Behavior.sit,
        4,
        tag: StepTag.meet,
        thought: bond == Bond.bestie ? '$name 자네. 옆에 있을래.' : '…자네. 옆에 있을래.',
      ),
    ];
  }
  return switch (bond) {
    Bond.none || Bond.stranger => [
      PetStep(
        Behavior.walk,
        12,
        targetX: guestX < 0.5 ? 0.7 : 0.3,
        thought: '…누구지?',
      ),
      const PetStep(Behavior.sit, 3, tag: StepTag.meet),
    ],
    Bond.sniff => [
      PetStep(Behavior.walk, 12, targetX: near),
      const PetStep(Behavior.sniff, 2.5, cue: Cue.sniff, thought: '킁킁… 이 냄새.'),
      const PetStep(Behavior.sit, 2, tag: StepTag.meet),
    ],
    Bond.play => [
      PetStep(Behavior.run, 8, targetX: near, cue: Cue.yip),
      const PetStep(Behavior.happy, 2.5, cue: Cue.bark, thought: '같이 놀자!'),
      const PetStep(Behavior.sit, 2, tag: StepTag.meet),
    ],
    Bond.bestie => [
      PetStep(Behavior.run, 8, targetX: near, cue: Cue.yip),
      PetStep(Behavior.happy, 2, cue: Cue.bark, thought: '$name! 왔다!'),
      const PetStep(Behavior.sit, 4, tag: StepTag.meet),
    ],
  };
}

/// 친구가 따라 하는 동작. 앉기류는 앉아 있던 애가 티 나게 한 번 일어났다 앉는다.
List<PetStep> mimicSteps(Trick t) {
  final b = mimicBehavior(t);
  return [
    if (b == Behavior.sit) const PetStep(Behavior.idle, 0.7),
    PetStep(b, 2.4),
  ];
}

/// 카페에서 펫이 개인기를 해내면 놀이 사이 넘는 친구가 따라 하는 동작. 자리에서 하는 것만.
Behavior mimicBehavior(Trick t) => switch (t) {
  Trick.sit || Trick.wait || Trick.potty => Behavior.sit,
  Trick.down => Behavior.lieBeside,
  Trick.spin => Behavior.spin,
  Trick.jump => Behavior.jump,
  Trick.fetch => Behavior.sniff,
  Trick.come || Trick.name => Behavior.happy,
};

/// 낮(10~18시)에 두 분마다 일곱 초, 창밖으로 누가 지나간다. 0~1은 지나가는 중의 위치, null은 없음.
/// [seed]로 펫마다 때가 다르다.
double? windowPass(DateTime t, int seed) {
  if (t.hour < 10 || t.hour >= 18) return null;
  // 초 밑 소수점까지 써야 창밖을 매끄럽게 지나간다. 초 단위면 1초마다 유리폭의 1/7씩 뛴다.
  final s =
      (t.hour * 3600 +
          t.minute * 60 +
          t.second +
          t.millisecond / 1000 +
          seed % 120) %
      120;
  return s < 7 ? s / 7 : null;
}

/// 카페에 꼭 와 있어야 하는 아는 강아지인지: 아직 못 만났거나 오늘(펫의 하루) 처음 만났다.
/// 처음 만나는 순간 '반쯤 옴'으로 바뀌면 같은 시간대에 다시 갔을 때 그 애가 빠질 수 있어서, 만난 날은 하루 내내 온다.
bool newcomerAt(Friendship? f, DateTime now) =>
    f == null ||
    f.bond == Bond.none ||
    (f.days == 1 && f.lastDay == dayKey(petDate(now)));

/// 어제 카페에서 만난 친구 중 오늘 창밖을 지나갈 애. 여럿이면 날마다 다른 애.
/// [candidates]는 카페에 오는 애 전부(단골과 아는 강아지).
Guest? passerFor(
  List<Guest> candidates,
  Map<String, Friendship> friends,
  DateTime now,
) {
  final day = petDate(now);
  final yesterday = dayKey(day.subtract(const Duration(days: 1)));
  final met = [
    for (final g in candidates)
      if (friends[g.id]?.lastDay == yesterday) g,
  ];
  if (met.isEmpty) return null;
  return met[(day.year * 400 + day.month * 31 + day.day) % met.length];
}
