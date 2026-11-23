import 'dart:math';

import 'cues.dart';

enum PetStage { puppy, adult }

enum Behavior {
  idle,
  walk,
  run,
  sit,
  sleep,
  eat,
  happy,
  sulk,
  lieBeside,
  waitAtDoor,
  watchWindow,
  sniff,

  /// 제자리에서 빙글빙글. 오래 비웠다 돌아왔을 때 파피용식 반김.
  spin,

  /// 제자리에서 폴짝폴짝. 기쁨 그림을 위아래로 띄워 그린다.
  jump,
}

enum Interaction { pet, feed }

const doorX = 0.12;

/// 창문 아래 바닥 위치. 비·눈 오는 날 여기 앉아 밖을 본다.
const windowX = 0.72;

/// 배변 패드 자리(오른쪽 구석). 쉬가 마려우면 여기로 데려간다.
const padX = 0.9;

/// 방석(방 가운데 깔린 러그) 자리. 낯가릴 땐 여기서 자고, 밑에 보물을 숨겨 둔다.
const rugX = 0.5;

/// 쉬가 마려워지는 간격. 앱을 열어 둔 동안만 흐른다.
const pottyEvery = Duration(hours: 3);

/// 쉬 자국이 남아 있는 시간.
const puddleLasts = Duration(seconds: 90);

/// 이 아래로 기운이 떨어지면 놀거나 산책하지 않고 쉰다. 버튼·자동 행동·AI 반응이 같은 기준을 쓴다.
const tiredEnergy = 20.0;

const greetAfter = Duration(hours: 4);

/// 친밀도 단계. 숫자 하나가 아니라 관계가 달라지는 느낌을 주려고 셋으로 나눈다.
enum Intimacy { stranger, friend, family }

Intimacy intimacyOf(double affection) {
  if (affection >= 67) return Intimacy.family;
  if (affection >= 34) return Intimacy.friend;
  return Intimacy.stranger;
}

String intimacyLabel(Intimacy i) => switch (i) {
  Intimacy.stranger => '낯가림',
  Intimacy.friend => '친함',
  Intimacy.family => '가족',
};

/// 가족이 되면 짧게 비워도 반긴다.
Duration greetAfterFor(Intimacy i) => switch (i) {
  Intimacy.stranger => const Duration(hours: 6),
  Intimacy.friend => greetAfter,
  Intimacy.family => const Duration(hours: 2),
};

/// 돌봄 점수. 아기가 성체가 되는 조건에 쓴다. 산책은 걸음 수에 따라 더 준다. 놀이는 공을 한 번 물어 올 때.
const careFeed = 2.0,
    carePlay = 3.0,
    carePet = 1.0,
    careTalk = 1.0,
    careReceive = 1.0,
    careTrick = 0.5,
    careWalkBase = 5.0;
const growDays = 14, growCare = 60.0;

bool shouldGrow(
  PetStage stage,
  DateTime bornAt,
  double careScore,
  DateTime now,
) =>
    stage == PetStage.puppy &&
    now.difference(bornAt).inDays >= growDays &&
    careScore >= growCare;

/// 날씨가 행동을 바꾼다. 비·눈이면 창가에 앉고, 더우면 늘어져 있는다.
enum WeatherMood { none, watchWindow, lazy }

class PetStats {
  const PetStats({
    required this.mood,
    required this.hunger,
    required this.energy,
    required this.affection,
  });

  final double mood;
  final double hunger;
  final double energy;
  final double affection;

  PetStats copyWith({
    double? mood,
    double? hunger,
    double? energy,
    double? affection,
  }) {
    return PetStats(
      mood: _clamp(mood ?? this.mood),
      hunger: _clamp(hunger ?? this.hunger),
      energy: _clamp(energy ?? this.energy),
      affection: _clamp(affection ?? this.affection),
    );
  }

  static double _clamp(double v) => v.clamp(0, 100).toDouble();
}

/// 공놀이 단계 표시. 컨트롤러가 이 단계에서 공을 줍거나 내려놓는다.
/// urge는 쉬가 마려워 킁킁대며 도는 동안(패드로 데려갈 수 있는 틈), potty는 패드로 가거나 실수하는 동작.
/// [pick]은 간식 가게에서 고른 칸 앞에 앉은 때(그때부터 고른 간식을 보여 준다),
/// [weigh]는 병원 체중계에 올라가 있는 때(체중계 화면에 몸무게가 뜬다),
/// [cut]은 홈캠 다시보기의 장면 전환(걸어가지 않고 그 자리로 바로 옮긴다),
/// [snack]은 손에서 받아 먹는 간식(밥그릇을 그리지 않는다),
/// [meet]은 카페 만남 장면의 끝(그때 친구 카드를 띄운다),
/// [mimic]은 개인기를 해낸 뒤 친구들이 따라 하기 시작하는 때,
/// [stamp]는 유치원 발표회의 끝(그때 연습으로 치고 도장을 붙인다),
/// [hand]는 손 베개에서 펫이 주인 손에 닿은 때, [beg]는 조르기의 한가운데(그 뒤 쓰다듬으면 앵긴다),
/// [unearth]는 가족이 된 날 방석 밑에 숨겨 둔 걸 꺼내 무는 때, [bowl]은 밥그릇을 그대로 그리는 때(먹기 전 앉아 기다릴 땐 담긴 그릇, 다 먹고 킁킁댈 땐 빈 그릇),
/// [door]는 아침 현관 물건(우산 등)을 입에 물고 있는 때, [praise]는 개인기를 해낸 뒤 간식 냄새를 맡는 때(칭찬 기회가 열린다).
enum StepTag {
  none,
  chase,
  carry,
  drop,
  urge,
  potty,
  pick,
  weigh,
  cut,
  snack,
  meet,
  mimic,
  stamp,
  hand,
  beg,
  unearth,
  bowl,
  door,
  praise,
}

class PetStep {
  const PetStep(
    this.behavior,
    this.seconds, {
    this.targetX,
    this.cue,
    this.tag = StepTag.none,
    this.thought,
  });

  final Behavior behavior;
  final double seconds;

  /// 방 바닥 가로 위치 0~1. 걷기·뛰기의 목적지, 문 앞 대기의 위치.
  final double? targetX;

  /// 이 단계를 시작할 때 낼 소리·진동과 띄울 속마음.
  final Cue? cue;
  final String? thought;
  final StepTag tag;
}

bool isNight(DateTime t) => t.hour >= 23 || t.hour < 7;

/// 하루는 새벽 5시에 바뀐다. 자정 넘어 쓰는 한밤 세션이 이틀로 쪼개지지 않게.
const dayStartHour = 5;

/// [t]가 속한 하루의 날짜(자정 시각). 새벽 4시는 아직 전날이다.
DateTime petDate(DateTime t) {
  return DateTime(t.year, t.month, t.day - (t.hour < dayStartHour ? 1 : 0));
}

/// [day]는 달력에 적힌 펫 날짜다. 현지 시각 05시 사이의 길이가 23시간 또는 25시간인 날도 있다.
DateTime petDayStart(DateTime day, {int offsetDays = 0}) =>
    DateTime(day.year, day.month, day.day + offsetDays, dayStartHour);

/// 첫날을 1로 세고, 현지 새벽 5시를 지날 때마다 함께한 날이 바뀐다.
int daysTogether(DateTime adopted, DateTime now) {
  DateTime calendarDay(DateTime time) {
    final day = petDate(time);
    return DateTime.utc(day.year, day.month, day.day);
  }

  return max(1, calendarDay(now).difference(calendarDay(adopted)).inDays + 1);
}

String dayKey(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// 하루에 오를 수 있는 친밀도. 쓰다듬기·공놀이·개인기·AI 대화·처음 보러 온 몫을 합쳐서 센다. 연타나 앱 다시
/// 켜기로 며칠 만에 '가족'이 되지 않게. 친해질수록 천천히 올라서, 매일 한도까지 놀아도 가족은 열흘, 최대는 삼 주쯤.
double dailyBondFor(Intimacy i) => switch (i) {
  Intimacy.stranger => 8,
  Intimacy.friend => 5,
  Intimacy.family => 3,
};

/// 밤 경계(23시·7시)와 배고픔 기준선을 넘는 순간 규칙이 바뀌므로 10분 단위로 나눠 계산한다.
/// [asleepAt]이 없으면 기본 밤(23~7시)에 잔다고 본다. 컨트롤러는 주인에게 배운 강아지의 밤과
/// 그 밤 길이에 맞춘 [sleepGain](잘 때 시간당 차는 기운)을 넘긴다.
PetStats applyElapsed(
  PetStats s,
  DateTime from,
  DateTime to, {
  bool napping = false,
  bool Function(DateTime)? asleepAt,
  double sleepGain = 12,
}) {
  const step = Duration(minutes: 10);
  const maxSpan = Duration(days: 14);
  if (!to.isAfter(from)) return s;
  if (to.difference(from) > maxSpan) from = to.subtract(maxSpan);

  var t = from;
  var mood = s.mood, hunger = s.hunger, energy = s.energy;
  while (t.isBefore(to)) {
    final next = t.add(step).isAfter(to) ? to : t.add(step);
    final hours = next.difference(t).inSeconds / 3600;
    final asleep = napping || (asleepAt ?? isNight)(t);
    hunger = min(100, hunger + 5 * hours);
    energy = asleep
        ? min(100, energy + sleepGain * hours)
        : max(0, energy - 3 * hours);
    final baseline = hunger >= 60 ? 35.0 : 65.0;
    final drift = 4 * hours;
    mood = mood < baseline
        ? min(baseline, mood + drift)
        : max(baseline, mood - drift);
    t = next;
  }
  return s.copyWith(mood: mood, hunger: hunger, energy: energy);
}

/// 타고난 성격. 펫마다 정해져 거의 변하지 않고, 같은 상황에서도 강아지마다 다르게 움직이게 한다.
class Traits {
  const Traits({required this.activity, required this.attachment});

  /// 활발함 0~1. 높을수록 잘 돌아다니고 덜 지치고 낮잠이 적다.
  final double activity;

  /// 애착 0~1. 높을수록 주인을 기다리고 크게 반긴다.
  final double attachment;

  static const plain = Traits(activity: 0.5, attachment: 0.5);

  /// 펫마다 늘 같은 성격이 나오게 번호로 뽑는다. 두 번 뽑아 평균 내서 극단적인 성격은 드물다.
  factory Traits.seeded(int seed) {
    final r = Random(seed);
    double pick() => (r.nextDouble() + r.nextDouble()) / 2;
    return Traits(activity: pick(), attachment: pick());
  }
}

/// 앱을 다시 열었을 때 반기는 정도. 비운 시간이 길수록 크게 반긴다.
/// [usual]은 늘 오는 때라 알고 기다린 가벼운 반김이다.
enum Greeting { none, hello, usual, big, huge, sleepy }

const _bigLines = ['왔다! 왔다!', '보고 싶었어!', '주인 냄새다!', '어디 갔다 왔어? 킁킁'];
const _hugeLines = ['드디어 왔다! 보고 싶었어!', '왔다왔다왔다!'];

/// 이보다 짧게 비우면 모른 척한다. 폰을 잠깐 껐다 켠 것까지 반기면 반김이 흔해진다.
const helloAfter = Duration(minutes: 30);
const hugeAfter = Duration(hours: 12);

/// [asleep]은 강아지가 자는 때인지(없으면 기본 밤), [drowsy]는 곧 잘 시간인지, [usual]은 주인이 보통
/// 이맘때 오는지(0~1)다. [random]이 없으면 늘 첫 번째 모습으로 반긴다.
({List<PetStep> steps, PetStats stats, Greeting greeting}) onReturn(
  PetStats s,
  Duration away,
  DateTime now, {
  Duration threshold = greetAfter,
  bool firstMeeting = false,
  bool? asleep,
  bool drowsy = false,
  double usual = 0,
  Traits traits = Traits.plain,
  Random? random,
}) {
  if (firstMeeting) {
    return (
      steps: const [
        PetStep(Behavior.sniff, 1.7, cue: Cue.sniff, thought: '킁… 처음 맡는 냄새.'),
        PetStep(Behavior.walk, 7, targetX: 0.5),
        PetStep(Behavior.happy, 2, cue: Cue.yip),
      ],
      stats: s,
      greeting: Greeting.hello,
    );
  }
  int pick(int n) => random == null ? 0 : random.nextInt(n);
  String line(List<String> lines) => lines[pick(lines.length)];
  final night = asleep ?? isNight(now);
  if (away < threshold) {
    if (night || away < helloAfter) {
      return (steps: const [], stats: s, greeting: Greeting.none);
    }
    return (
      steps: traits.attachment > 0.65 && pick(2) == 1
          ? const [
              PetStep(Behavior.run, 3, targetX: 0.5, cue: Cue.yip),
              PetStep(Behavior.happy, 1.5),
            ]
          : const [
              PetStep(Behavior.sit, 1.2, cue: Cue.yip),
              PetStep(Behavior.happy, 1.5),
            ],
      stats: s.copyWith(mood: s.mood + 2),
      greeting: Greeting.hello,
    );
  }
  // 밤에는 뛰어나오지 않는다. 주인을 많이 따르는 애는 꼬리를 흔들고, 덜 따르는 애는 계속 잔다.
  if (night) {
    return (
      steps: traits.attachment < 0.3
          ? const [PetStep(Behavior.sleep, 30, thought: '…쿨.')]
          : traits.attachment > 0.65
          ? const [
              PetStep(
                Behavior.sit,
                1.5,
                cue: Cue.sigh,
                thought: '…왔다. 졸려도 좋아.',
              ),
              PetStep(Behavior.happy, 1.2),
              PetStep(Behavior.sleep, 30),
            ]
          : const [
              PetStep(Behavior.sit, 3, cue: Cue.sigh, thought: '…왔어? 나 졸려.'),
              PetStep(Behavior.sleep, 30),
            ],
      stats: s.copyWith(mood: s.mood + 3),
      greeting: Greeting.sleepy,
    );
  }
  // 잘 시간이 다가오면 달려 나오지 않고 느릿느릿 와서 기댄다.
  if (drowsy && away < hugeAfter) {
    return (
      steps: [
        PetStep(
          Behavior.walk,
          5,
          targetX: 0.5,
          cue: Cue.yip,
          thought: line(const ['기다렸어… 졸린데.', '왔구나. 하암.']),
        ),
        const PetStep(Behavior.happy, 2),
        const PetStep(Behavior.sit, 4, cue: Cue.sigh),
      ],
      stats: s.copyWith(mood: s.mood + 5),
      greeting: Greeting.big,
    );
  }
  // 늘 오는 때라 알고 기다렸다. 매일 같은 시각에 크게 달려 나오면 반김이 뻔해진다.
  if (usual >= 0.6 && away < hugeAfter) {
    return (
      steps: traits.attachment >= 0.5
          ? [
              PetStep(
                Behavior.waitAtDoor,
                1.5,
                targetX: doorX,
                cue: Cue.yip,
                thought: line(const ['올 줄 알았어!', '딱 이맘때 오지!']),
              ),
              const PetStep(Behavior.happy, 2),
            ]
          : [
              PetStep(
                Behavior.sit,
                1.2,
                cue: Cue.yip,
                thought: line(const ['또 왔네!', '왔어?']),
              ),
              const PetStep(Behavior.happy, 1.5),
            ],
      stats: s.copyWith(mood: s.mood + 4),
      greeting: Greeting.usual,
    );
  }
  if (away < hugeAfter) {
    final ways = [
      [
        PetStep(
          Behavior.waitAtDoor,
          2.5,
          targetX: doorX,
          thought: line(_bigLines),
        ),
        const PetStep(Behavior.run, 4, cue: Cue.bark, targetX: 0.5),
        const PetStep(Behavior.happy, 3, cue: Cue.bark),
      ],
      const [
        PetStep(Behavior.waitAtDoor, 1.5, targetX: doorX),
        PetStep(Behavior.sniff, 1.5, cue: Cue.sniff, thought: '킁킁… 주인 냄새!'),
        PetStep(Behavior.run, 4, cue: Cue.bark, targetX: 0.5),
        PetStep(Behavior.happy, 2, cue: Cue.bark),
      ],
      // 빙글 돌기는 12시간 넘게 기다린 날 몫이라 활발한 애도 여기선 우다다 뛰기만 한다.
      if (traits.activity > 0.55)
        [
          PetStep(
            Behavior.run,
            2.5,
            cue: Cue.bark,
            targetX: 0.85,
            thought: line(_bigLines),
          ),
          const PetStep(Behavior.run, 2.5, targetX: 0.3),
          const PetStep(Behavior.run, 2, targetX: 0.5),
          const PetStep(Behavior.happy, 2, cue: Cue.bark),
        ],
    ];
    return (
      steps: ways[pick(ways.length)],
      stats: s.copyWith(mood: s.mood + 5),
      greeting: Greeting.big,
    );
  }
  return (
    steps: [
      PetStep(
        Behavior.waitAtDoor,
        2.5,
        targetX: doorX,
        thought: line(_hugeLines),
      ),
      const PetStep(Behavior.run, 4, cue: Cue.bark, targetX: 0.5),
      const PetStep(Behavior.spin, 2.4, cue: Cue.bark),
      const PetStep(Behavior.happy, 1.5),
      const PetStep(Behavior.spin, 2.4),
      const PetStep(Behavior.happy, 3, cue: Cue.bark),
    ],
    stats: s.copyWith(mood: s.mood + 6),
    greeting: Greeting.huge,
  );
}

PetStep chooseNext(
  PetStats s,
  DateTime now,
  Random random, {
  WeatherMood weather = WeatherMood.none,
  Intimacy intimacy = Intimacy.friend,
  bool? asleep,
  Traits traits = Traits.plain,
  bool puppy = false,
  bool napAllowed = true,
}) {
  if ((asleep ?? isNight(now)) || s.energy < tiredEnergy) {
    return const PetStep(Behavior.sleep, 30);
  }
  final roll = random.nextDouble();
  if (s.hunger > 75 || s.mood < 30) {
    return roll < 0.6
        ? const PetStep(Behavior.sulk, 8)
        : const PetStep(Behavior.idle, 5);
  }
  // 아기와 덜 활발한 애는 낮에도 자주 존다. 주인이 만져서 깨운 뒤에는 한동안 안 존다.
  final nap = napAllowed
      ? (puppy ? 0.07 : 0.025) * (1.5 - traits.activity)
      : 0.0;
  if (roll < nap) {
    return PetStep(Behavior.sleep, 20 + random.nextDouble() * 20);
  }
  if (weather == WeatherMood.watchWindow && roll < 0.5) {
    return const PetStep(Behavior.watchWindow, 12, targetX: windowX);
  }
  if (weather == WeatherMood.lazy && roll < 0.5) {
    return const PetStep(Behavior.lieBeside, 10);
  }
  // 가족이 되면 가끔 제 발로 앞에 와서 앉는다. 낯가리는 동안은 가운데로 잘 안 온다.
  if (intimacy == Intimacy.family && roll < 0.15) {
    return const PetStep(Behavior.run, 4, targetX: 0.5);
  }
  if (roll < 0.25 + 0.3 * traits.activity) {
    final range = intimacy == Intimacy.stranger ? 0.45 : 0.65;
    return PetStep(
      Behavior.walk,
      6,
      targetX: 0.2 + random.nextDouble() * range,
    );
  }
  if (roll < 0.85) return PetStep(Behavior.idle, 4 + random.nextDouble() * 4);
  return const PetStep(Behavior.sit, 6);
}

/// [bond]가 아니면 친밀도는 오르지 않는다. 연타만으로 몇 분 만에 '가족'이 되지 않게 컨트롤러가 시간 간격을 둔다.
({PetStats stats, PetStep step}) react(
  PetStats s,
  Interaction interaction, {
  required bool sleeping,
  required bool cooledDown,
  bool bond = true,
}) {
  switch (interaction) {
    case Interaction.pet:
      if (sleeping) return (stats: s, step: const PetStep(Behavior.sit, 2.5));
      final next = cooledDown
          ? s.copyWith(
              mood: s.mood + 6,
              affection: s.affection + (bond ? 2 : 0),
            )
          : s;
      return (
        stats: next,
        step: const PetStep(Behavior.happy, 2.5, cue: Cue.pop),
      );
    case Interaction.feed:
      if (s.hunger < 10) {
        return (stats: s, step: const PetStep(Behavior.sit, 2));
      }
      return (
        stats: s.copyWith(hunger: s.hunger - 35, mood: s.mood + 4),
        step: const PetStep(Behavior.eat, 3, cue: Cue.crunch),
      );
  }
}

/// 공을 한 번 물어 오면 기분이 오르고 조금 지친다.
PetStats afterFetch(
  PetStats s, {
  required bool bond,
  Traits traits = Traits.plain,
}) => s.copyWith(
  mood: s.mood + 4,
  energy: s.energy - 3 * (1.3 - traits.activity * 0.6),
  affection: s.affection + (bond ? 1 : 0),
);

/// 산책을 마치면 기분이 좋아지고 조금 지친다. 걸음이 많을수록 돌봄 점수가 더 오른다.
({PetStats stats, double care}) afterWalk(
  PetStats s,
  int steps,
  Duration length,
) {
  final minutes = length.inMinutes.clamp(0, 120);
  return (
    stats: s.copyWith(
      mood: s.mood + 10 + min(10, minutes / 3),
      energy: s.energy - min(25, 5 + minutes / 4),
      affection: s.affection + 2,
    ),
    care: careWalkBase + steps / 500,
  );
}
