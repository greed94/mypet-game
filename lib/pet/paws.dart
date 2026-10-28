import 'dart:math';

/// 발도장. 펫과 지낸 일로 버는 놀이 용돈이다. 돈으로 팔지 않는다(대표 결정 2026-10-03,
/// docs/meetings/2026-10-03-수익화-생각.md). 밥·물·병원 같은 기본 돌봄은 발도장과 상관없다.

/// 하루에 버는 발도장 상한(기본값). 이정표(처음 배운 개인기·단짝·함께한 날)는 상한 밖이다.
const pawsDailyCap = 10;

/// 산책 5분에 하나, 한 번에 여섯까지(기본값).
int walkPaws(Duration length) => min(6, max(0, length.inMinutes ~/ 5));

/// 들어준 소원, 발표회 도장, 검진, 하루 끝 이야기(저녁에 처음 말 걸기)(기본값).
const wishPaws = 2;
const recitalPaws = 3;
const checkupPaws = 2;
const eveningTalkPaws = 1;

/// 저녁 이야기는 이 시각부터(기본값).
const eveningFrom = 18;

/// 이정표 발도장(기본값). 같은 이정표는 한 번만.
const trickMilestonePaws = 5;
const bestieMilestonePaws = 5;
const togetherMilestones = {7: 5, 30: 10, 100: 20};

/// 오늘 몫 안에서 줄 수 있는 만큼.
int cappedPaws(int want, {required int earnedToday}) =>
    max(0, min(want, pawsDailyCap - earnedToday));

/// 받은 이정표들. DB에는 쉼표로 이어 둔다('trick:sit', 'bestie:coco', 'days:7').
Set<String> parseMarks(String? csv) =>
    csv == null || csv.isEmpty ? {} : csv.split(',').toSet();

String marksToCsv(Set<String> marks) => (marks.toList()..sort()).join(',');

enum CosmeticKind { collar, rug }

/// 발도장으로 바꾸는 꾸미기. 처음 것(값 0)은 처음부터 있다.
class Cosmetic {
  const Cosmetic(this.id, this.label, this.kind, this.colors, this.price);

  final String id;
  final String label;
  final CosmeticKind kind;

  /// 목걸이는 한 색, 방석은 바깥·가운데·안쪽 세 색.
  final List<int> colors;
  final int price;
}

const cosmetics = [
  Cosmetic('collar_red', '빨강 목걸이', CosmeticKind.collar, [0xFFD64040], 0),
  Cosmetic('collar_sky', '하늘 목걸이', CosmeticKind.collar, [0xFF4FA3D1], 8),
  Cosmetic('collar_leaf', '풀잎 목걸이', CosmeticKind.collar, [0xFF6AAF5E], 8),
  Cosmetic('collar_yellow', '노랑 목걸이', CosmeticKind.collar, [0xFFF2C14E], 8),
  Cosmetic('collar_pink', '분홍 목걸이', CosmeticKind.collar, [0xFFE8A0B4], 8),
  Cosmetic('collar_violet', '보라 목걸이', CosmeticKind.collar, [0xFF9B7FD1], 8),
  Cosmetic('collar_navy', '남색 목걸이', CosmeticKind.collar, [0xFF3B4A8C], 8),
  Cosmetic('rug_lavender', '라벤더 방석', CosmeticKind.rug, [
    0xFFC9BCEC,
    0xFFE4DCF8,
    0xFFD6CBF3,
  ], 0),
  Cosmetic('rug_mint', '민트 방석', CosmeticKind.rug, [
    0xFFA9D9C3,
    0xFFD6F0E3,
    0xFFC0E5D2,
  ], 12),
  Cosmetic('rug_peach', '복숭아 방석', CosmeticKind.rug, [
    0xFFF0BBA4,
    0xFFFBE0D3,
    0xFFF5CBB8,
  ], 12),
  Cosmetic('rug_sky', '하늘 방석', CosmeticKind.rug, [
    0xFFAFCDEB,
    0xFFDCEAF8,
    0xFFC5DBF1,
  ], 12),
];

Cosmetic? cosmeticById(String id) {
  for (final c in cosmetics) {
    if (c.id == id) return c;
  }
  return null;
}

/// 처음부터 가진 꾸미기.
Set<String> get freeCosmetics => {
  for (final c in cosmetics)
    if (c.price == 0) c.id,
};

/// 지금 목걸이 색에 맞는 꾸미기(없으면 처음 것).
Cosmetic collarFor(int accent) => cosmetics.firstWhere(
  (c) => c.kind == CosmeticKind.collar && c.colors.first == accent,
  orElse: () => cosmetics.first,
);
