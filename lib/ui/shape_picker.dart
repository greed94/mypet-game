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
  static void resetCache() => _PetSpritePreviewState._sheets.clear();

  final PetColors colors;
  final String selected;
  final ValueChanged<String> onSelect;

  /// 설정에서는 지금 단계로 보여 줘야 방에 나오는 모습과 같다. 온보딩은 자란 모습으로 고르게 한다.
  final PetStage stage;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;
    return C3SystemTextScale.restore(
      context,
      child: LayoutBuilder(
        builder: (context, bounds) {
          // 13px 이름을 아홉 글자 정도 읽을 수 있는 폭에서 다음 열을 연다.
          final minimum = 16 + MediaQuery.textScalerOf(context).scale(13) * 9;
          final available = bounds.hasBoundedWidth ? bounds.maxWidth : 140.0;
          final columns = ((available + spacing) / (minimum + spacing))
              .floor()
              .clamp(1, 3);
          final width = (available - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final shape in shapes)
                // 개인 사진으로 만든 틀은 이미 쓰는 펫에게만 계속 보여 준다.
                if (shape.id != 'noeul' || shape.id == selected)
                  SizedBox(
                    width: width,
                    child: _ShapeCard(
                      shape: shape,
                      colors: colors,
                      stage: stage,
                      selected: shape.id == selected,
                      onTap: () {
                        if (!context.mounted ||
                            ModalRoute.of(context)?.isCurrent == false) {
                          return;
                        }
                        onSelect(shape.id);
                      },
                    ),
                  ),
            ],
          );
        },
      ),
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
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: selected ? C3Colors.stampInk : C3Colors.line,
        width: selected ? 2.5 : 1.5,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: shape.examples,
      child: Material(
        color: C3Colors.card,
        shape: border,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: border,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    children: [
                      PetSpritePreview(
                        shape: shape.id,
                        colors: colors,
                        stage: stage,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shape.examples,
                        textAlign: TextAlign.center,
                        style: C3Text.label.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.check_circle,
                      size: 19,
                      color: C3Colors.stampInk,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 집에 나올 강아지의 실제 시트와 선택한 털색을 보여 준다.
class PetSpritePreview extends StatefulWidget {
  const PetSpritePreview({
    super.key,
    required this.shape,
    required this.colors,
    required this.stage,
    this.dimension = 96,
    this.sitting = false,
    this.accent = defaultAccent,
    this.onRendered,
  });

  final String shape;
  final PetColors colors;
  final PetStage stage;
  final double dimension;
  final bool sitting;
  final int accent;

  /// 현재 요청의 그림 또는 대체 표시를 한 프레임 그린 뒤 알려 준다.
  final ValueChanged<bool>? onRendered;

  @override
  State<PetSpritePreview> createState() => _PetSpritePreviewState();
}

class _PetSpritePreviewState extends State<PetSpritePreview> {
  static final _sheets = <String, Future<ui.Image>>{};
  ui.Image? _image;
  int _request = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PetSpritePreview old) {
    super.didUpdateWidget(old);
    final c = widget.colors, o = old.colors;
    if (widget.shape != old.shape ||
        widget.stage != old.stage ||
        widget.accent != old.accent ||
        c.main != o.main ||
        c.second != o.second ||
        c.marking != o.marking) {
      _load();
    }
  }

  Future<void> _load() async {
    final mine = ++_request;
    final previous = _image;
    _image = null;
    _failed = false;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    final c = widget.colors;
    final asset = 'assets/${spriteAsset(widget.shape, widget.stage)}';
    final loading = _sheets[asset] ??= _decode(asset);
    try {
      final sheet = await loading;
      if (!mounted || mine != _request) return;
      final (image, _) = await paintSheet(
        sheet,
        main: c.main,
        second: c.second,
        accent: widget.accent,
        marking: c.marking,
      );
      if (!mounted || mine != _request) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (identical(_sheets[asset], loading)) _sheets.remove(asset);
      if (!mounted || mine != _request) return;
      setState(() => _failed = true);
    }
    if (widget.onRendered != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && mine == _request) widget.onRendered?.call(!_failed);
      });
    }
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return SizedBox.square(
      dimension: widget.dimension,
      child: _failed
          ? const Icon(Icons.pets_outlined, semanticLabel: '모습을 불러오지 못했어요')
          : image == null
          ? const Icon(
              Icons.more_horiz,
              color: C3Colors.line,
              semanticLabel: '모습 불러오는 중',
            )
          : CustomPaint(painter: _FramePainter(image, widget.sitting)),
    );
  }
}

/// 서 있거나 앉은 첫 프레임을 정수배로 그린다.
class _FramePainter extends CustomPainter {
  _FramePainter(this.sheet, this.sitting);

  final ui.Image sheet;
  final bool sitting;

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
      Rect.fromLTWH(0, sitting ? 6 * frame : 0, frame, frame),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.sheet != sheet || old.sitting != sitting;
}
