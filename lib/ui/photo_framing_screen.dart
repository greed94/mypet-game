import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../art/photo_art.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import 'c3/c3_theme.dart';
import 'shape_picker.dart';

Future<PetPhotoSelection?> editPetPhoto(
  BuildContext context,
  PreparedPetPhoto photo,
  PetPhotoSelection initial, {
  required String shape,
  required PetStage stage,
  required int accent,
}) => Navigator.of(context).push<PetPhotoSelection>(
  MaterialPageRoute(
    builder: (_) => PhotoFramingScreen(
      photo: photo,
      initial: initial,
      shape: shape,
      stage: stage,
      accent: accent,
    ),
  ),
);

/// 같은 편집기를 입양, 아는 강아지, 설정의 사진 선택에 쓴다.
class PhotoFrameButton extends StatelessWidget {
  const PhotoFrameButton({
    super.key,
    required this.photo,
    required this.onApply,
    this.shape = 'papillon',
    this.stage = PetStage.puppy,
    this.accent = defaultAccent,
  });
  final String shape;
  final PetStage stage;
  final int accent;
  final EditablePetPhoto photo;
  final ValueChanged<EditablePetPhoto>? onApply;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.crop, size: 18),
    label: const Text('얼굴 위치 맞추기'),
    onPressed: onApply == null
        ? null
        : () async {
            final result = await editPetPhoto(
              context,
              photo.source,
              photo.selection,
              shape: shape,
              stage: stage,
              accent: accent,
            );
            if (context.mounted && result != null) {
              onApply?.call((source: photo.source, selection: result));
            }
          },
  );
}

class PhotoFramingScreen extends StatefulWidget {
  const PhotoFramingScreen({
    super.key,
    required this.photo,
    required this.initial,
    required this.shape,
    required this.stage,
    required this.accent,
  });
  final String shape;
  final PetStage stage;
  final int accent;
  final PreparedPetPhoto photo;
  final PetPhotoSelection initial;

  @override
  State<PhotoFramingScreen> createState() => _PhotoFramingScreenState();
}

class _PhotoFramingScreenState extends State<PhotoFramingScreen> {
  late PhotoFrame _frame = widget.initial.frame;
  late PetPhotoSelection _preview = widget.initial;
  Timer? _timer;
  bool _running = false;
  String? _error;
  bool _loadingInitial = false;
  bool _initialPainted = false;
  Offset? _dragCenter;

  Uint8List? _renderedSpriteFor;
  bool _spriteAvailable = true;
  int _spriteRetry = 0;
  bool get _pixelsReady => _initialPainted && identical(_preview.frame, _frame);
  bool get _ready =>
      _pixelsReady && identical(_renderedSpriteFor, _preview.look.portrait);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingInitial && !_initialPainted && _error == null) _loadInitial();
  }

  Future<void> _cachePixels(Uint8List bytes) async {
    Object? failure;
    await precacheImage(
      MemoryImage(bytes),
      context,
      onError: (error, _) => failure = error,
    );
    if (failure != null) throw StateError('preview');
  }

  Future<void> _loadInitial() async {
    _loadingInitial = true;
    try {
      await Future.wait([
        _cachePixels(widget.photo.pixels),
        _cachePixels(widget.initial.look.portrait),
      ]);
      if (mounted) {
        setState(() {
          _initialPainted = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '사진을 불러오지 못했어요.');
    } finally {
      _loadingInitial = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _change(PhotoFrame frame) {
    final value = frame.fitted(widget.photo.width, widget.photo.height);
    final before = _frame.square(widget.photo.width, widget.photo.height);
    final after = value.square(widget.photo.width, widget.photo.height);
    if (before == after && _frame.zoom == value.zoom) return;
    setState(() {
      _frame = value;
      _error = null;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 110), _refresh);
  }

  Future<void> _refresh() async {
    if (!mounted || _pixelsReady || _running) return;
    final requested = _frame;
    _running = true;
    try {
      final look = await compute(renderPetPhoto, (
        pixels: widget.photo.pixels,
        frame: requested,
      ));
      if (!mounted || !identical(requested, _frame)) return;
      await _cachePixels(look.portrait);
      if (mounted && identical(requested, _frame)) {
        setState(() {
          _preview = (frame: requested, look: look);
          _error = null;
        });
      }
    } on EmptyPhotoArea {
      if (mounted && identical(requested, _frame)) {
        setState(() => _error = '빈 영역이에요. 얼굴이 보이는 곳으로 옮겨 주세요.');
      }
    } catch (_) {
      if (mounted && identical(requested, _frame)) {
        setState(() => _error = '미리보기를 읽지 못했어요.');
      }
    } finally {
      _running = false;
      if (mounted && !identical(requested, _frame)) {
        _timer?.cancel();
        _timer = Timer(Duration.zero, _refresh);
      }
    }
  }

  void _move(double dx, double dy) {
    final base = _frame.fitted(widget.photo.width, widget.photo.height);
    double step(double delta, int length) => delta == 0
        ? 0
        : delta.sign * (delta.abs() < 1 / length ? 1 / length : delta.abs());
    _change(
      PhotoFrame(
        x: base.x + step(dx, widget.photo.width),
        y: base.y + step(dy, widget.photo.height),
        zoom: base.zoom,
      ),
    );
  }

  Widget _swatch(String role, int argb) {
    final red = (argb >> 16) & 255,
        green = (argb >> 8) & 255,
        blue = argb & 255;
    const names = <int, String>{
      0x272420: '검정',
      0x858486: '회색',
      0xF7F5EF: '흰색',
      0xE7CDA7: '크림색',
      0xB5804A: '황갈색',
      0x745035: '갈색',
      0x73A4A1: '청록색',
      0x6C8CAB: '파란색',
      0x90A473: '초록색',
      0xD39E9A: '분홍색',
    };
    int distance(int swatch) {
      final r = red - ((swatch >> 16) & 255),
          g = green - ((swatch >> 8) & 255),
          b = blue - (swatch & 255);
      return r * r + g * g + b * b;
    }

    final nearest = names.keys.reduce(
      (a, b) => distance(a) <= distance(b) ? a : b,
    );
    return Semantics(
      label: '$role, ${names[nearest]}, RGB $red, $green, $blue',
      child: ExcludeSemantics(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(color: C3Colors.line),
          ),
        ),
      ),
    );
  }

  Widget _picture() {
    final photo = widget.photo;
    final area = _frame.square(photo.width, photo.height);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: AspectRatio(
        aspectRatio: photo.width / photo.height,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final rect = Rect.fromLTWH(
              area.left * w / photo.width,
              area.top * h / photo.height,
              area.side * w / photo.width,
              area.side * h / photo.height,
            );
            return Semantics(
              label: '원본 사진의 선택 영역',
              value:
                  '가로 ${(_frame.x * 100).round()}%, 세로 ${(_frame.y * 100).round()}%, ${_frame.zoom.toStringAsFixed(1)}배 확대',
              child: GestureDetector(
                key: const ValueKey('pet-photo-frame'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapUp: (e) => _change(
                  PhotoFrame(
                    x: e.localPosition.dx / w,
                    y: e.localPosition.dy / h,
                    zoom: _frame.zoom,
                  ),
                ),
                onPanStart: (_) {
                  final fitted = _frame.fitted(photo.width, photo.height);
                  _dragCenter = Offset(fitted.x, fitted.y);
                },
                onPanUpdate: (e) {
                  final previous = _dragCenter;
                  if (previous == null) return;
                  final sx = area.side / (2 * photo.width),
                      sy = area.side / (2 * photo.height);
                  final next = Offset(
                    (previous.dx + e.delta.dx / w).clamp(sx, 1 - sx),
                    (previous.dy + e.delta.dy / h).clamp(sy, 1 - sy),
                  );
                  _dragCenter = next;
                  _change(
                    PhotoFrame(x: next.dx, y: next.dy, zoom: _frame.zoom),
                  );
                },
                onPanEnd: (_) => _dragCenter = null,
                onPanCancel: () => _dragCenter = null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      photo.pixels,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                    CustomPaint(painter: _FrameOutline(rect)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _arrow(String label, IconData icon, double dx, double dy) =>
      IconButton(
        tooltip: label,
        icon: Icon(icon),
        onPressed: () => _move(dx, dy),
      );

  @override
  Widget build(BuildContext context) {
    final look = _preview.look;
    return Scaffold(
      backgroundColor: C3Colors.paper,
      appBar: AppBar(title: const Text('얼굴 위치 맞추기')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '얼굴을 누르거나 테두리를 옮겨 주세요.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 10),
                          Center(child: _picture()),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('확대'),
                              Expanded(
                                child: Slider(
                                  value: _frame.zoom,
                                  min: 1,
                                  max: 3,
                                  divisions: 20,
                                  semanticFormatterCallback: (v) =>
                                      '${v.toStringAsFixed(1)}배',
                                  onChanged: (v) => _change(
                                    PhotoFrame(
                                      x: _frame.x,
                                      y: _frame.y,
                                      zoom: v,
                                    ),
                                  ),
                                ),
                              ),
                              Text('${_frame.zoom.toStringAsFixed(1)}배'),
                            ],
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              _arrow('왼쪽으로', Icons.arrow_back, -.05, 0),
                              _arrow('위로', Icons.arrow_upward, 0, -.05),
                              _arrow('아래로', Icons.arrow_downward, 0, .05),
                              _arrow('오른쪽으로', Icons.arrow_forward, .05, 0),
                              TextButton(
                                onPressed: () => _change(const PhotoFrame()),
                                child: const Text('가운데로'),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  look.portrait,
                                  width: 78,
                                  height: 78,
                                  filterQuality: FilterQuality.none,
                                  gaplessPlayback: true,
                                  semanticLabel: '선택한 영역으로 만든 픽셀 초상화',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _error ??
                                          (!_ready
                                              ? '미리보기 만드는 중…'
                                              : _spriteAvailable
                                              ? '픽셀 초상화와 털색'
                                              : '강아지 그림을 읽지 못했어요. 초상화와 털색은 저장할 수 있어요.'),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _swatch('주 털', look.colors.main),
                                        _swatch('보조 털', look.colors.second),
                                        _swatch('무늬', look.colors.marking),
                                      ],
                                    ),
                                    if (_ready && !_spriteAvailable)
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _renderedSpriteFor = null;
                                          _spriteRetry++;
                                        }),
                                        child: const Text('강아지 그림 다시 읽기'),
                                      ),
                                    if (_error != null &&
                                        !_error!.startsWith('빈 영역'))
                                      TextButton(
                                        onPressed: _initialPainted
                                            ? _refresh
                                            : _loadInitial,
                                        child: const Text('다시 읽기'),
                                      ),
                                  ],
                                ),
                              ),
                              PetSpritePreview(
                                key: ValueKey((look.portrait, _spriteRetry)),
                                onRendered: (ok) {
                                  if (!mounted ||
                                      !identical(
                                        _preview.look.portrait,
                                        look.portrait,
                                      )) {
                                    return;
                                  }
                                  setState(() {
                                    _renderedSpriteFor = look.portrait;
                                    _spriteAvailable = ok;
                                  });
                                },
                                shape: widget.shape,
                                stage: widget.stage,
                                accent: widget.accent,
                                colors: look.colors,
                                dimension: 66,
                                sitting: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _ready
                        ? () => Navigator.of(context).pop(_preview)
                        : null,
                    child: const Text('이 영역 사용'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameOutline extends CustomPainter {
  const _FrameOutline(this.frame);
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .44));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black54;
    canvas.drawRect(frame.deflate(1.5), edge);
    edge
      ..strokeWidth = 1.5
      ..color = Colors.white;
    canvas.drawRect(frame.deflate(1.5), edge);
  }

  @override
  bool shouldRepaint(_FrameOutline previous) => previous.frame != frame;
}
