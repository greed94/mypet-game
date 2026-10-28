import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/photo_art.dart';
import '../game/sprite_art.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import 'c3/c3_theme.dart';

/// 모양 틀을 우리 아이 털색으로 칠해 나란히 보여 주고 하나를 고르게 한다.
class ShapePicker extends StatelessWidget {
  const ShapePicker({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelect,
    this.stage = PetStage.adult,
    this.shapes = dogShapes,
  });

  /// 고를 수 있는 틀. 아는 강아지는 실험 틀을 뺀 [friendShapes].
  final List<DogShape> shapes;

  /// 위젯 테스트는 테스트마다 시계(zone)가 따로라, 앞 테스트에서 시작한 시트 읽기가 끝나지 않은 채 남는다.
  @visibleForTesting
  static void resetCache() => _ThumbState._sheets.clear();

  final PetColors colors;
  final String selected;
  final ValueChanged<String> onSelect;

  /// 설정에서는 지금 단계로 보여 줘야 방에 나오는 모습과 같다. 온보딩은 자란 모습으로 고르게 한다.
  final PetStage stage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final shape in shapes)
          // 개인 사진으로 만든 틀은 이미 쓰는 펫에게만 계속 보여 준다.
          if (shape.id != 'noeul' || shape.id == selected)
            _ShapeCard(
              shape: shape,
              colors: colors,
              stage: stage,
              selected: shape.id == selected,
              onTap: () => onSelect(shape.id),
            ),
      ],
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    required this.shape,
    required this.colors,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final DogShape shape;
  final PetColors colors;
  final PetStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: shape.examples,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: C3Colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? C3Colors.stamp : C3Colors.line,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            children: [
              _Thumb(shape: shape.id, colors: colors, stage: stage),
              const SizedBox(height: 6),
              Text(
                shape.examples,
                textAlign: TextAlign.center,
                style: C3Text.label.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({
    required this.shape,
    required this.colors,
    required this.stage,
  });

  final String shape;
  final PetColors colors;
  final PetStage stage;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  static final _sheets = <String, Future<ui.Image>>{};
  late Future<ui.Image> _image = _paint();

  @override
  void didUpdateWidget(_Thumb old) {
    super.didUpdateWidget(old);
    final c = widget.colors, o = old.colors;
    if (widget.shape != old.shape ||
        widget.stage != old.stage ||
        c.main != o.main ||
        c.second != o.second ||
        c.marking != o.marking) {
      _image = _paint();
    }
  }

  Future<ui.Image> _paint() async {
    final asset = 'assets/${spriteAsset(widget.shape, widget.stage)}';
    final sheet = await (_sheets[asset] ??= _decode(asset));
    final c = widget.colors;
    final (image, _) = await paintSheet(
      sheet,
      main: c.main,
      second: c.second,
      accent: defaultAccent,
      marking: c.marking,
    );
    return image;
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 96,
      child: FutureBuilder<ui.Image>(
        future: _image,
        builder: (context, snap) => snap.data == null
            ? const SizedBox()
            : CustomPaint(painter: _FramePainter(snap.data!)),
      ),
    );
  }
}

/// 시트의 첫 칸(서 있는 모습)만 정수배로 키워 그린다.
class _FramePainter extends CustomPainter {
  _FramePainter(this.sheet);

  final ui.Image sheet;

  @override
  void paint(Canvas canvas, Size size) {
    const frame = spriteFrame * 1.0;
    final k = (size.shortestSide / frame).floorToDouble();
    final side = frame * k;
    final dst = Rect.fromLTWH(
      ((size.width - side) / 2).roundToDouble(),
      ((size.height - side) / 2).roundToDouble(),
      side,
      side,
    );
    canvas.drawImageRect(
      sheet,
      const Rect.fromLTWH(0, 0, frame, frame),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.sheet != sheet;
}
