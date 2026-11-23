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
  try {
    return _colorsFromSquare(
      _square(
        _pixelsOnly(img.bakeOrientation(decoded)),
        const PhotoFrame(),
        64,
      ),
    );
  } on EmptyPhotoArea {
    return null;
  }
}

PetColors _colorsFromSquare(img.Image small) {
  const size = 64;
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
      if (p.a == 0) continue;
      samples.add(
        _Sample(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), w * p.a / 255),
      );
    }
  }

  // 투명 스티커의 귀나 꼬리만 모서리에 걸린 경우에도 실제로 보이는 픽셀을 쓴다.
  if (samples.isEmpty) {
    for (final p in small) {
      if (p.a > 0) {
        samples.add(
          _Sample(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), p.a / 255),
        );
      }
    }
    if (samples.isEmpty) throw const EmptyPhotoArea();
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
  final patch = _square(
    _pixelsOnly(img.bakeOrientation(decoded)),
    const PhotoFrame(),
    size,
  );
  if (!patch.any((p) => p.a > 0)) return null;
  return _portraitFromSquare(patch);
}

class EmptyPhotoArea implements Exception {
  const EmptyPhotoArea();
}

Uint8List _portraitFromSquare(img.Image square) {
  // 16색 양자화는 알파를 저장하지 않으므로 보이는 색만 앱 종이 위에 합성한다.
  final paper = _pixelsOnly(square);
  for (final pixel in paper) {
    final opacity = pixel.a / 255;
    if (opacity == 1) continue;
    int mix(num value, int base) =>
        (value * opacity + base * (1 - opacity)).round();
    pixel.setRgba(mix(pixel.r, 251), mix(pixel.g, 247), mix(pixel.b, 239), 255);
  }
  return img.encodePng(
    img.quantize(
      paper,
      numberOfColors: 16,
      method: img.QuantizeMethod.neuralNet,
    ),
  );
}

img.Image _pixelsOnly(img.Image source) {
  final rgba = source.convert(
    format: img.Format.uint8,
    numChannels: 4,
    withPalette: false,
    noAnimation: true,
  );
  final data = rgba.getBytes(order: img.ChannelOrder.rgba);
  for (var i = 0; i < data.length; i += 4) {
    if (data[i + 3] == 0) data[i] = data[i + 1] = data[i + 2] = 0;
  }
  return img.Image.fromBytes(
    width: rgba.width,
    height: rgba.height,
    bytes: data.buffer,
    bytesOffset: data.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
}

/// 원본을 기기에 저장하지 않고 편집할 작은 사진과 중앙의 초기 결과를 만든다.
/// 호출부는 이미지 디코딩·양자화를 별도 isolate에서 실행한다.
typedef PetPhotoLook = ({PetColors colors, Uint8List portrait});
typedef PreparedPetPhoto = ({
  Uint8List pixels,
  int width,
  int height,
  PetPhotoLook initial,
  PhotoFrame initialFrame,
});
typedef PetPhotoSelection = ({PhotoFrame frame, PetPhotoLook look});

typedef EditablePetPhoto = ({
  PreparedPetPhoto source,
  PetPhotoSelection selection,
});

EditablePetPhoto centerPetPhoto(PreparedPetPhoto photo) => (
  source: photo,
  selection: (frame: photo.initialFrame, look: photo.initial),
);

class PhotoFrame {
  const PhotoFrame({this.x = .5, this.y = .5, this.zoom = 1});
  final double x;
  final double y;
  final double zoom;

  ({int left, int top, int side}) square(int width, int height) {
    final side = max(1, (min(width, height) / zoom.clamp(1.0, 3.0)).round());
    return (
      left: (x * width - side / 2).round().clamp(0, width - side),
      top: (y * height - side / 2).round().clamp(0, height - side),
      side: side,
    );
  }

  PhotoFrame fitted(int width, int height) {
    final r = square(width, height);
    return PhotoFrame(
      x: (r.left + r.side / 2) / width,
      y: (r.top + r.side / 2) / height,
      zoom: zoom.clamp(1.0, 3.0),
    );
  }
}

img.Image _square(img.Image source, PhotoFrame frame, int size) {
  final r = frame.square(source.width, source.height);
  final crop = img.copyCrop(
    source,
    x: r.left,
    y: r.top,
    width: r.side,
    height: r.side,
  );
  return _resizePhoto(crop, size, size);
}

/// 투명한 배경을 섞을 때 보이는 색의 합을 알파의 합으로 나눈다.
img.Image _resizePhoto(img.Image source, int width, int height) {
  if (source.width == width && source.height == height) return source;
  if (!source.any((p) => p.a != 255)) {
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }
  final pixels = source.getBytes(order: img.ChannelOrder.rgba);
  final resized = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; ++y) {
    final top = y * source.height ~/ height;
    final bottom = max(top + 1, (y + 1) * source.height ~/ height);
    for (var x = 0; x < width; ++x) {
      final left = x * source.width ~/ width;
      final right = max(left + 1, (x + 1) * source.width ~/ width);
      int alphaSum = 0, redSum = 0, greenSum = 0, blueSum = 0;
      for (var row = top; row < bottom; row++) {
        for (var col = left; col < right; col++) {
          final offset = 4 * (row * source.width + col);
          final a = pixels[offset + 3];
          alphaSum += a;
          redSum += pixels[offset] * a;
          greenSum += pixels[offset + 1] * a;
          blueSum += pixels[offset + 2] * a;
        }
      }
      final count = (right - left) * (bottom - top);
      final alpha = (alphaSum / count).round();
      if (alpha > 0) {
        resized.setPixelRgba(
          x,
          y,
          (redSum / alphaSum).round(),
          (greenSum / alphaSum).round(),
          (blueSum / alphaSum).round(),
          alpha,
        );
      }
    }
  }
  return resized;
}

/// 초기 정사각형은 짧은 변을 전부 쓰므로 긴 변 한 축에서만 보이는 면적을 비교한다.
PhotoFrame? _visibleFrame(img.Image photo) {
  final horizontal = photo.width >= photo.height;
  final length = max(photo.width, photo.height);
  final side = min(photo.width, photo.height);
  final opacity = Uint32List(length);
  for (final p in photo) {
    opacity[horizontal ? p.x : p.y] += p.a.toInt();
  }
  int sum = 0, best = 0, bestStart = 0;
  for (var index = 0; index < length; index++) {
    sum += opacity[index];
    if (index >= side) sum -= opacity[index - side];
    if (index < side - 1 || sum == 0) continue;
    final start = index - side + 1;
    if (sum > best ||
        (sum == best &&
            (2 * start + side - length).abs() <
                (2 * bestStart + side - length).abs())) {
      best = sum;
      bestStart = start;
    }
  }
  if (best == 0) return null;
  final center = (bestStart + side / 2) / length;
  return PhotoFrame(
    x: horizontal ? center : 0.5,
    y: horizontal ? 0.5 : center,
  ).fitted(photo.width, photo.height);
}

PetPhotoLook _look(img.Image source, PhotoFrame frame) {
  final patch = _square(source, frame, 64);
  return (
    colors: _colorsFromSquare(patch),
    portrait: _portraitFromSquare(patch),
  );
}

PreparedPetPhoto? preparePetPhoto(Uint8List bytes) {
  final decoded = _decodePhoto(bytes);
  if (decoded == null) return null;
  final upright = _pixelsOnly(img.bakeOrientation(decoded));
  final scale = min(1.0, 768 / max(upright.width, upright.height));
  final preview = scale == 1
      ? upright
      : _resizePhoto(
          upright,
          max(1, (upright.width * scale).round()),
          max(1, (upright.height * scale).round()),
        );
  var frame = const PhotoFrame();
  PetPhotoLook initial;
  try {
    initial = _look(preview, frame);
  } on EmptyPhotoArea {
    final visible = _visibleFrame(preview);
    if (visible == null) return null;
    frame = visible;
    try {
      initial = _look(preview, frame);
    } on EmptyPhotoArea {
      return null;
    }
  }
  return (
    pixels: img.encodePng(preview),
    width: preview.width,
    height: preview.height,
    initial: initial,
    initialFrame: frame,
  );
}

PetPhotoLook renderPetPhoto(({Uint8List pixels, PhotoFrame frame}) input) {
  // pixels는 preparePetPhoto가 새로 인코딩한 작은 PNG다.
  final preview = img.decodePng(input.pixels)!;
  return _look(preview, input.frame);
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
