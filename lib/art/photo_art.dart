import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PetColors {
  const PetColors({
    required this.main,
    required this.second,
    required this.marking,
  });

  final int main;
  final int second;
  final int marking;
}

/// 사진 없이 고르는 털색(이름, 주 털, 보조 털, 무늬). 온보딩과 아는 강아지 데려오기가 같이 쓴다.
const furPresets = [
  ('흰색', 0xFFF8F1E6, 0xFFFFFDF8, 0xFF914F28),
  ('갈색', 0xFFC48C54, 0xFFF4E2C4, 0xFF8A5E3B),
  ('크림', 0xFFE8D5B0, 0xFFFFF6E6, 0xFFC8A070),
  ('검정', 0xFF3A3230, 0xFF8C7B72, 0xFF3A3230),
  ('회색', 0xFF9A9AA0, 0xFFE0E0E4, 0xFF5C5C63),
];

img.Image? _decodePhoto(Uint8List bytes) {
  try {
    return img.decodeImage(bytes);
  } on RangeError {
    // 일부 형식 판별기는 짧거나 잘린 파일을 확인하면서 범위를 벗어난다.
    return null;
  } on FormatException {
    return null;
  } on img.ImageException {
    return null;
  }
}

/// 사진 가운데(피사체가 있을 자리)에 무게를 두고 색을 여섯 무리로 묶는다.
/// 가장 큰 무리가 주 털, 채도가 높은 무리가 무늬. 바닥·벽은 대개 채도가 낮아 무늬로 잘못 잡히지 않는다.
/// 실패(사진을 못 읽음)하면 null.
PetColors? extractPetColors(Uint8List bytes) {
  final decoded = _decodePhoto(bytes);
  if (decoded == null) return null;
  const size = 64;
  final small = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: size,
    interpolation: img.Interpolation.average,
  );

  final samples = <_Sample>[];
  const center = size / 2, sigma = 13.0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final w = exp(
        -((x - center) * (x - center) + (y - center) * (y - center)) /
            (2 * sigma * sigma),
      );
      if (w < 0.03) continue;
      final p = small.getPixel(x, y);
      samples.add(_Sample(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), w));
    }
  }

  // 실내 사진은 어둡게 찍혀 흰 털이 회색으로 나온다. 밝은 쪽 5%가 거의 흰색이 되도록 밝기를 맞춘다.
  final levels = samples.map((s) => (s.r + s.g + s.b) / 3).toList()..sort();
  final p95 =
      levels[(levels.length * 0.95).floor().clamp(0, levels.length - 1)];
  final gain = (245 / max(p95, 1.0)).clamp(1.0, 1.8);
  final leveled = [
    for (final s in samples)
      _Sample(
        min(255, s.r * gain),
        min(255, s.g * gain),
        min(255, s.b * gain),
        s.w,
      ),
  ];

  final clusters = _kMeans(leveled, 6);
  final members = {for (final c in clusters) c: <_Sample>[]};
  for (final s in leveled) {
    double d(_Cluster c) =>
        (c.r - s.r) * (c.r - s.r) +
        (c.g - s.g) * (c.g - s.g) +
        (c.b - s.b) * (c.b - s.b);
    members[clusters.reduce((a, b) => d(a) <= d(b) ? a : b)]!.add(s);
  }
  final total = clusters.fold(0.0, (a, c) => a + c.weight);
  _Cluster? marking;
  for (final c in clusters) {
    // 무늬는 따뜻한 색(붉은 갈색·주황 계열)만. 파란 장난감이나 옷은 털이 아니다.
    if (c.weight / total < 0.04 || c.saturation < 0.18 || c.b > c.r) continue;
    if (marking == null ||
        c.saturation * c.weight > marking.saturation * marking.weight) {
      marking = c;
    }
  }
  final mainCandidates = clusters.where(
    (c) => c != marking && (marking == null || c.distanceTo(marking) > 40),
  );
  final main = (mainCandidates.isEmpty ? clusters : mainCandidates).reduce(
    (a, b) => a.weight >= b.weight ? a : b,
  );
  // 검은 무늬는 채도가 없어 위에서 안 잡힌다. 주 털보다 훨씬 어두운 큰 무리가 있으면 그것이 무늬다.
  marking ??= clusters
      .where(
        (c) =>
            c != main &&
            c.weight / total >= 0.08 &&
            c.brightness < main.brightness - 70,
      )
      .fold<_Cluster?>(
        null,
        (best, c) => best == null || c.weight > best.weight ? c : best,
      );

  // 사진 속 털은 그림자 때문에 실제보다 어둡고 탁하다. 밝은 쪽·선명한 쪽 픽셀로 대표색을 잡는다.
  final mainColor = _representative(
    members[main]!,
    (s) => s.r + s.g + s.b,
    0.35,
  );
  final markingColor = marking == null
      ? mainColor
      : _representative(members[marking]!, _sat, 0.4);
  return PetColors(
    main: mainColor,
    second: _lighten(mainColor, _bright(mainColor) > 170 ? 0.5 : 0.3),
    marking: markingColor,
  );
}

int _representative(
  List<_Sample> members,
  double Function(_Sample) score,
  double topFraction,
) {
  if (members.isEmpty) return 0xFF808080;
  final sorted = [...members]..sort((a, b) => score(b).compareTo(score(a)));
  var r = 0.0, g = 0.0, b = 0.0, w = 0.0;
  for (final s in sorted.take(max(1, (sorted.length * topFraction).round()))) {
    r += s.r * s.w;
    g += s.g * s.w;
    b += s.b * s.w;
    w += s.w;
  }
  return 0xFF000000 |
      ((r / w).round() << 16) |
      ((g / w).round() << 8) |
      (b / w).round();
}

double _sat(_Sample s) {
  final hi = max(s.r, max(s.g, s.b)), lo = min(s.r, min(s.g, s.b));
  return hi <= 0 ? 0 : (hi - lo) / hi;
}

double _bright(int c) =>
    0.299 * ((c >> 16) & 0xFF) + 0.587 * ((c >> 8) & 0xFF) + 0.114 * (c & 0xFF);

/// 사진을 64×64, 16색으로 줄인 픽셀 초상화 PNG.
Uint8List? pixelPortraitPng(Uint8List bytes, {int size = 64}) {
  final decoded = _decodePhoto(bytes);
  if (decoded == null) return null;
  final square = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: size,
    interpolation: img.Interpolation.average,
  );
  return img.encodePng(
    img.quantize(
      square,
      numberOfColors: 16,
      method: img.QuantizeMethod.neuralNet,
    ),
  );
}

class _Sample {
  const _Sample(this.r, this.g, this.b, this.w);
  final double r, g, b, w;
}

class _Cluster {
  _Cluster(this.r, this.g, this.b);
  double r, g, b;
  double weight = 0;

  int get argb => 0xFF000000 | (r.round() << 16) | (g.round() << 8) | b.round();
  double get brightness => 0.299 * r + 0.587 * g + 0.114 * b;
  double get saturation {
    final hi = max(r, max(g, b)), lo = min(r, min(g, b));
    return hi <= 0 ? 0 : (hi - lo) / hi;
  }

  double distanceTo(_Cluster o) => sqrt(
    (r - o.r) * (r - o.r) + (g - o.g) * (g - o.g) + (b - o.b) * (b - o.b),
  );
}

/// 밝기 순으로 고르게 뽑은 시작점에서 12번 돌린다. 사진 한 장이라 이 정도면 충분히 수렴한다.
List<_Cluster> _kMeans(List<_Sample> samples, int k) {
  final sorted = [...samples]
    ..sort((a, b) => (a.r + a.g + a.b).compareTo(b.r + b.g + b.b));
  final clusters = [
    for (var i = 0; i < k; i++)
      _Cluster(
        sorted[(sorted.length - 1) * i ~/ (k - 1)].r,
        sorted[(sorted.length - 1) * i ~/ (k - 1)].g,
        sorted[(sorted.length - 1) * i ~/ (k - 1)].b,
      ),
  ];
  for (var iter = 0; iter < 12; iter++) {
    final sums = List.generate(k, (_) => [0.0, 0.0, 0.0, 0.0]);
    for (final s in samples) {
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < k; i++) {
        final c = clusters[i];
        final d =
            (s.r - c.r) * (s.r - c.r) +
            (s.g - c.g) * (s.g - c.g) +
            (s.b - c.b) * (s.b - c.b);
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      final acc = sums[best];
      acc[0] += s.r * s.w;
      acc[1] += s.g * s.w;
      acc[2] += s.b * s.w;
      acc[3] += s.w;
    }
    for (var i = 0; i < k; i++) {
      final acc = sums[i];
      clusters[i].weight = acc[3];
      if (acc[3] > 0) {
        clusters[i]
          ..r = acc[0] / acc[3]
          ..g = acc[1] / acc[3]
          ..b = acc[2] / acc[3];
      }
    }
  }
  return clusters.where((c) => c.weight > 0).toList();
}

int _lighten(int c, double k) {
  int ch(int v) => (v + (255 - v) * k).round().clamp(0, 255);
  return 0xFF000000 |
      (ch((c >> 16) & 0xFF) << 16) |
      (ch((c >> 8) & 0xFF) << 8) |
      ch(c & 0xFF);
}
