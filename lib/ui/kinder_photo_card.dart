import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../game/sprite_art.dart';
import '../pet/guest.dart';
import '../pet/kinder_photo.dart';
import '../pet/kindergarten.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import '../pet/tricks.dart';
import 'c3/c3_theme.dart';
import 'c3/tape.dart';

typedef _Dog = (ui.Image, Map<(int, int), (int, int)>);

/// 유치원 오늘의 한 장. 그날 일기 아래에 폴라로이드처럼 붙는다.
/// 펫은 지금 모습·털색에 그날 성장 단계로, 친구들은 그날 유치원에 온 애들로 그린다.
class KinderPhotoCard extends StatefulWidget {
  const KinderPhotoCard({super.key, required this.photo, required this.pet});

  final KinderPhotoRow photo;
  final Pet pet;

  static const width = 236.0;

  /// 위젯 테스트는 테스트마다 시계(zone)가 따로라, 앞 테스트에서 시작한 칠하기가 끝나지 않은 채 남는다.
  @visibleForTesting
  static void resetCache() {
    _KinderPhotoCardState._painted.clear();
    _KinderPhotoCardState._decoded.clear();
  }

  @override
  State<KinderPhotoCard> createState() => _KinderPhotoCardState();
}

class _KinderPhotoCardState extends State<KinderPhotoCard> {
  static final _painted = <String, Future<_Dog>>{};
  static final _decoded = <String, Future<ui.Image>>{};

  late Future<(List<_Dog>, ui.Image)> _art;

  @override
  void initState() {
    super.initState();
    _art = _load();
  }

  @override
  void didUpdateWidget(KinderPhotoCard old) {
    super.didUpdateWidget(old);
    if (old.photo != widget.photo || old.pet != widget.pet) _art = _load();
  }

  /// 펫, 친구들 순서.
  List<Guest> get _dogs {
    final p = widget.pet;
    return [
      Guest(
        id: 'me',
        shape: p.shape,
        look: '',
        main: p.furMain,
        second: p.furSecond,
        marking: p.marking,
        accent: p.accent,
        puppy: widget.photo.stage == PetStage.puppy,
      ),
      for (final id in widget.photo.friends.split(','))
        ...kinderFriends.where((g) => g.id == id),
    ];
  }

  Future<(List<_Dog>, ui.Image)> _load() async => (
    await Future.wait([for (final g in _dogs) _paint(g)]),
    await _decode('assets/sprites/props.png'),
  );

  static Future<_Dog> _paint(Guest g) {
    final key =
        '${g.shape}_${g.puppy}_${g.main}_${g.second}_${g.marking}_${g.accent}';
    return _painted[key] ??= () async {
      final stage = g.puppy ? PetStage.puppy : PetStage.adult;
      final sheet = await _decode('assets/${spriteAsset(g.shape, stage)}');
      return paintSheet(
        sheet,
        main: g.main,
        second: g.second,
        accent: g.accent,
        marking: g.marking,
      );
    }();
  }

  static Future<ui.Image> _decode(String asset) =>
      _decoded[asset] ??= () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      }();

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final scene = KinderScene.values.asNameMap()[photo.scene];
    if (scene == null) return const SizedBox.shrink();
    final t = photo.trick;
    final trick = t == null ? null : Trick.values.asNameMap()[t];
    return Transform.rotate(
      angle: -0.03,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: KinderPhotoCard.width,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            decoration: BoxDecoration(
              color: C3Colors.card,
              border: Border.all(color: C3Colors.line),
              boxShadow: const [
                BoxShadow(
                  color: C3Colors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: FutureBuilder<(List<_Dog>, ui.Image)>(
                    future: _art,
                    builder: (context, snap) =>
                        CustomPaint(painter: _ScenePainter(scene, snap.data)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '유치원 · ${kinderCaption(scene, trick)}',
                  style: C3Text.pet.copyWith(
                    fontSize: 17,
                    color: C3Colors.ink2,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: -9,
            left: KinderPhotoCard.width / 2 - 34,
            child: Tape(
              width: 68,
              height: 18,
              color: C3Colors.tapeYellow,
              angle: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 시트 줄(AGENTS.md 스프라이트 규격).
const _walk = 1, _sleep = 2, _eat = 3, _happy = 4, _sit = 6, _sniff = 7;

/// 장면마다 (줄, 칸, 가로 위치, 왼쪽을 보는지). 펫, 친구1, 친구2 순서.
const _poses = {
  KinderScene.play: [
    (_happy, 1, 0.5, false),
    (_sniff, 0, 0.19, false),
    (_happy, 2, 0.81, true),
  ],
  KinderScene.run: [
    (_walk, 2, 0.5, false),
    (_walk, 0, 0.18, false),
    (_walk, 1, 0.82, false),
  ],
  KinderScene.lunch: [
    (_eat, 1, 0.5, false),
    (_eat, 0, 0.17, false),
    (_eat, 2, 0.83, false),
  ],
  KinderScene.nap: [
    (_sleep, 0, 0.5, false),
    (_sleep, 0, 0.19, false),
    (_sleep, 0, 0.81, true),
  ],
  KinderScene.lesson: [
    (_sit, 0, 0.5, false),
    (_sit, 0, 0.18, false),
    (_sit, 0, 0.82, true),
  ],
};

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.art);

  final KinderScene scene;
  final (List<_Dog>, ui.Image)? art;

  static final _pixel = Paint()..filterQuality = FilterQuality.none;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, floor = h * 0.62;
    final paint = Paint();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, floor),
      paint..color = const Color(0xFFFFF3D6),
    );
    paint.color = const Color(0xFFFBE6B8);
    for (var y = 22.0; y < floor - 8; y += 18) {
      for (var x = ((y ~/ 18).isEven ? 9.0 : 18.0); x < w; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
    // 유치원 방의 가랜드와 매트를 줄여 그린다.
    const flags = [0xFFF4AAB7, 0xFFBFE5C8, 0xFFBAD9F4, 0xFFF7E196];
    const n = 7;
    for (var i = 0; i < n; i++) {
      final x0 = w * i / n + 2, x1 = w * (i + 1) / n - 2;
      canvas.drawPath(
        Path()
          ..moveTo(x0, 4)
          ..lineTo(x1, 4)
          ..lineTo((x0 + x1) / 2, 15)
          ..close(),
        paint..color = Color(flags[i % flags.length]),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, floor - 4, w, 4),
      paint..color = const Color(0xFFE9CFA0),
    );
    const mats = [0xFFFFDDE4, 0xFFD9F1E1, 0xFFDDEBFA, 0xFFFFF1C6];
    final tileW = w / 4, tileH = (h - floor) / 2;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * tileW, floor + row * tileH, tileW, tileH),
          paint..color = Color(mats[(row + col) % mats.length]),
        );
      }
    }

    final a = art;
    if (a != null) {
      final (dogs, props) = a;
      final k = (h * 0.5 / spriteFrame).floorToDouble().clamp(1.0, 6.0);
      final bottom = floor + (h - floor) * 0.72;
      final poses = _poses[scene]!;
      for (var i = 0; i < dogs.length && i < poses.length; i++) {
        final (row, col, x, left) = poses[i];
        _dog(canvas, dogs[i], props, row, col, w * x, bottom, k, left);
      }
    }
    if (scene == KinderScene.nap) {
      // 낮잠 시간엔 불을 끈다(방에서도 낮잠 땐 어둡다).
      canvas.drawRect(
        Offset.zero & size,
        paint..color = const Color(0x332C3E66),
      );
    }
  }

  void _dog(
    Canvas canvas,
    _Dog dog,
    ui.Image props,
    int row,
    int col,
    double cx,
    double bottom,
    double k,
    bool left,
  ) {
    final (sheet, mouths) = dog;
    const f = spriteFrame * 1.0;
    final origin = Offset(cx - f / 2 * k, bottom - f * k);
    final (mx, _) = mouthAt(mouths, row, col);
    canvas.save();
    if (left) {
      canvas.translate(cx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-cx, 0);
    }
    canvas.drawImageRect(
      sheet,
      Rect.fromLTWH(col * f, row * f, f, f),
      origin & Size(f * k, f * k),
      _pixel,
    );
    // 소품은 방에서와 같은 자리에(밥그릇은 입 앞 바닥, 하트는 머리 위).
    switch (row) {
      case _eat:
        _prop(canvas, props, 0, origin + Offset(mx - 9.0, 17) * k, k);
      case _happy when scene == KinderScene.play && !left:
        _prop(canvas, props, 1, origin + Offset(mx - 12.0, -6) * k, k);
      default:
    }
    canvas.restore();
    if (row == _sleep) {
      // z는 뒤집히면 이상해서 강아지가 왼쪽을 봐도 똑바로 둔다.
      final x = origin.dx + (mx - 4) * k;
      _prop(
        canvas,
        props,
        2,
        Offset((left ? 2 * cx - x : x) - 8 * k, origin.dy + 2 * k),
        k,
      );
    }
  }

  void _prop(Canvas canvas, ui.Image props, int cell, Offset at, double k) {
    canvas.drawImageRect(
      props,
      Rect.fromLTWH(cell * 16.0, 0, 16, 16),
      at & Size(16 * k, 16 * k),
      _pixel,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene || old.art != art;
}
