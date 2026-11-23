import 'dart:convert';
import 'dart:math';

import 'guest.dart' show stableHash;

/// 산책 블랙박스(아이디어 C4). 위치를 재지 않아서 길은 그날 정해진 낙서이고,
/// 오래 킁킁댄 자리는 산책 중 킁킁 동작마다 하나씩(셋까지) 동네 흔한 곳에서 고른다.
const walkSpotNames = [
  '전봇대 밑',
  '풀숲',
  '벤치 밑',
  '꽃밭',
  '가로수 아래',
  '골목 모퉁이',
  '자전거 세워 둔 곳',
  '화단',
  '편의점 앞',
  '놀이터 모래밭',
];

/// 킁킁댄 자리. [at]은 길 위 어디쯤인지(0~1).
typedef WalkSpot = ({String name, double at});

/// 산책이 끝났을 때 본 지도를 그대로 다시 펴기 위한 값. 시작 시각이 낙서 길의 씨앗이다.
typedef WalkResult = ({
  int steps,
  int minutes,
  int finds,
  DateTime startedAt,
  List<WalkSpot> spots,
});

String encodeWalkMap(WalkResult walk, {String? receipt}) => jsonEncode({
  'v': 1,
  'receipt': ?receipt,
  'startMs': walk.startedAt.millisecondsSinceEpoch,
  'minutes': walk.minutes,
  'steps': walk.steps,
  'finds': walk.finds,
  'spots': [
    for (final spot in walk.spots) [spot.name, spot.at],
  ],
});

/// 구버전 기록과 읽을 수 없는 그림은 기존에 저장한 한 줄로 보여 준다.
WalkResult? decodeWalkMap(String? value) {
  if (value == null) return null;
  try {
    final data = jsonDecode(value);
    if (data case {
      'v': 1,
      'startMs': int start,
      'minutes': int minutes,
      'steps': int steps,
      'finds': int finds,
      'spots': List points,
    } when minutes > 0 && steps >= 0 && finds >= 0 && points.length <= 3) {
      final spots = <WalkSpot>[];
      for (final point in points) {
        if (point case [
          String name,
          num at,
        ] when name.isNotEmpty && at >= 0 && at <= 1) {
          spots.add((name: name, at: at.toDouble()));
        } else {
          return null;
        }
      }
      return (
        startedAt: DateTime.fromMillisecondsSinceEpoch(start),
        steps: steps,
        minutes: minutes,
        finds: finds,
        spots: spots,
      );
    }
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
  return null;
}

/// 산책에서 오래 킁킁댄 자리들(길 순서대로). 비 오는 날엔 물웅덩이가 끼고, 눈 오는 날엔 눈 쌓인 화단이.
List<WalkSpot> walkSpots(
  DateTime start,
  int sniffs, {
  bool rain = false,
  bool snow = false,
}) {
  final n = min(3, sniffs);
  if (n == 0) return const [];
  final r = Random(stableHash('walk:${start.millisecondsSinceEpoch}'));
  final pool = [
    if (rain) '물웅덩이',
    if (snow) '눈 쌓인 화단',
    ...[...walkSpotNames]..shuffle(r),
  ];
  return [
    for (var i = 0; i < n; i++)
      (name: pool[i], at: (i + 1) / (n + 1) + (r.nextDouble() - 0.5) * 0.12),
  ];
}

/// 길 낙서: 왼쪽 집에서 오른쪽 집까지 구불구불한 점들(0~1 좌표). 산책마다 다르다.
List<(double, double)> walkPath(DateTime start) {
  final r = Random(stableHash('path:${start.millisecondsSinceEpoch}'));
  const n = 7;
  return [
    for (var i = 0; i < n; i++)
      (i / (n - 1), i == 0 || i == n - 1 ? 0.5 : 0.2 + r.nextDouble() * 0.6),
  ];
}

/// 일기 재료. 첫 킁킁 자리 하나.
String? walkSpotLine(List<WalkSpot> spots) =>
    spots.isEmpty ? null : '산책길 ${spots.first.name}에서 한참 킁킁댔다';
