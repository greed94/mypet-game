import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../art/photo_art.dart';
import '../data/database.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import '../services/notifications.dart';
import '../services/telemetry.dart';
import '../services/weather.dart';
import 'c3/c3_theme.dart';
import 'c3/paper.dart';
import 'c3/polaroid.dart';
import 'c3/room_backdrop.dart';
import 'keep_words.dart';
import 'shape_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.db,
    required this.weather,
    required this.onCreated,
    this.clock,
  });

  final AppDatabase db;
  final WeatherService weather;
  final Future<void> Function(Pet pet) onCreated;
  final DateTime Function()? clock;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  final _name = TextEditingController();
  final _place = TextEditingController();

  PetColors? _colors;
  Uint8List? _portrait;
  bool _fromPhoto = false;
  bool _picking = false;
  int _photoGen = 0;
  int _searchGen = 0;
  PetStage _stage = PetStage.puppy;
  String _shape = dogShapes.first.id;
  List<Place> _places = const [];
  Place? _chosen;
  bool _searching = false;
  bool _dailyReminders = false;
  bool _creating = false;
  bool _finished = false;
  Pet? _createdPet;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (!mounted ||
        _step != 0 ||
        _picking ||
        _creating ||
        _createdPet != null) {
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final mine = ++_photoGen;
    bool current() => mounted && mine == _photoGen;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (!current()) return;
      if (file == null) {
        Telemetry.track('photo_pick', {'result': 'cancel'});
        return;
      }
      final bytes = await file.readAsBytes();
      if (!current()) return;
      final colors = extractPetColors(bytes);
      final portrait = pixelPortraitPng(bytes);
      if (colors == null || portrait == null) {
        Telemetry.track('photo_pick', {'result': 'unreadable'});
        _snack('사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
        return;
      }
      Telemetry.track('photo_pick', {
        'result': 'ok',
        'main':
            '#${(colors.main & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'marking':
            '#${(colors.marking & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      });
      setState(() {
        _colors = colors;
        _portrait = portrait;
        _fromPhoto = true;
      });
    } on PlatformException {
      if (current()) _snack('사진을 열지 못했어요. 다시 골라 볼까요?');
    } on FileSystemException {
      if (current()) _snack('사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
    } finally {
      if (current()) setState(() => _picking = false);
    }
  }

  void _choosePreset(int i) {
    if (_step != 0 || _creating || _createdPet != null) return;
    _photoGen++;
    final p = furPresets[i];
    Telemetry.track('preset', {'color': p.$1});
    setState(() {
      _picking = false;
      _colors = PetColors(main: p.$2, second: p.$3, marking: p.$4);
      _portrait = null;
      _fromPhoto = false;
    });
  }

  void _searchChanged() {
    if (_step != 2 || _creating || _createdPet != null) return;
    _searchGen++;
    setState(() {
      _places = const [];
      _chosen = null;
      _searching = false;
    });
  }

  Future<void> _search() async {
    if (!mounted || _step != 2 || _creating || _createdPet != null) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final mine = ++_searchGen;
    final query = _place.text.trim();
    setState(() => _searching = true);
    final results = await widget.weather.search(query);
    if (!mounted || mine != _searchGen) return;
    Telemetry.track('place_search', {'results': results.length});
    setState(() {
      _places = results;
      _searching = false;
    });
    if (results.isEmpty) _snack('찾지 못했어요. 시·구 이름으로 다시 해볼까요?');
  }

  Future<void> _create() async {
    if (!mounted || _step != 2 || _creating || _finished) return;
    final colors = _colors;
    final name = _name.text.trim();
    if (colors == null || name.isEmpty) return;
    final stage = _stage;
    final shape = _shape;
    final chosen = _chosen;
    final fromPhoto = _fromPhoto;
    final portrait = _portrait;
    _photoGen++;
    _searchGen++;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() {
      _creating = true;
      _searching = false;
    });
    File? portraitFile;
    try {
      if (_createdPet == null) {
        if (portrait != null) {
          final dir = await getApplicationDocumentsDirectory();
          if (!mounted) return;
          portraitFile = File(
            '${dir.path}/portrait-${DateTime.now().microsecondsSinceEpoch}.png',
          );
          await portraitFile.writeAsBytes(portrait, flush: true);
          if (!mounted) return;
        }
        final now = (widget.clock ?? DateTime.now)();
        _createdPet = await widget.db.transaction(() async {
          final pet = await widget.db.createPet(
            name: name,
            stage: stage,
            furMain: colors.main,
            furSecond: colors.second,
            marking: colors.marking,
            shape: shape,
            now: now,
            regionName: chosen?.name,
            latitude: chosen?.lat,
            longitude: chosen?.lon,
            portraitPath: portraitFile?.path,
          );
          await widget.db.queueFirstMeeting(now);
          return pet;
        });
        if (!mounted) return;
        var granted = false;
        try {
          if (_dailyReminders) {
            granted = await Notifications.requestPermission();
          }
        } on Exception {
          // 알림 실패가 이미 저장한 펫의 첫 시작을 막지 않게 한다.
        }
        if (!mounted) return;
        Telemetry.track('pet_created', {
          'stage': stage.name,
          'shape': shape,
          'from_photo': fromPhoto,
          'has_region': chosen != null,
          'notifications': granted,
        });
        if (granted) {
          try {
            await Notifications.scheduleDaily(name);
          } on Exception {
            // 알림은 부가 기능이다. 펫을 다시 저장하지 않고 홈으로 이어간다.
          }
        }
      }
      if (!mounted) return;
      await widget.onCreated(_createdPet!);
      _finished = true;
    } on Exception {
      if (mounted) {
        _snack(
          _createdPet == null
              ? '저장하지 못했어요. 다시 시작해 볼까요?'
              : '펫은 저장됐어요. 시작을 다시 눌러 주세요.',
        );
      }
    } finally {
      if (_createdPet == null && portraitFile != null) {
        try {
          if (await portraitFile.exists()) await portraitFile.delete();
        } on FileSystemException {
          // 실패한 작업의 연결되지 않은 파일만 정리한다.
        }
      }
      if (mounted) setState(() => _creating = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _go(int step) {
    if (_creating || _createdPet != null || step == _step) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (_step == 0) {
        _photoGen++;
        _picking = false;
      }
      if (_step == 2) {
        _searchGen++;
        _searching = false;
      }
      _step = step;
    });
    Telemetry.track('onboarding_step', {'to': step});
    _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_creating && (_step == 0 || _createdPet != null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _go(_step - 1);
      },
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_lookPage(), _namePage(), _placePage()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lookPage() {
    final colors = _colors;
    return _Page(
      title: '어떤 아이인가요?',
      subtitle: '사진을 올리면 털색을 뽑아 우리 아이 색으로 칠해요. 사진이 없으면 색만 골라도 돼요.',
      footer: '속마음과 일기에는 AI를 사용할 수 있어요. 연결이 없을 때도 강아지는 반응하고 일기를 써요.',
      next: colors == null ? null : () => _go(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _picking ? null : _pickPhoto,
            icon: const Icon(Icons.photo),
            label: Text(_picking ? '읽는 중…' : '사진으로 만들기'),
          ),
          const SizedBox(height: 16),
          Text('또는 색 고르기', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < furPresets.length; i++)
                ChoiceChip(
                  label: Text(furPresets[i].$1),
                  avatar: CircleAvatar(
                    backgroundColor: Color(furPresets[i].$2),
                  ),
                  selected: !_fromPhoto && colors?.main == furPresets[i].$2,
                  onSelected: (_) => _choosePreset(i),
                ),
            ],
          ),
          if (colors != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (_portrait != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _portrait!,
                      width: 96,
                      height: 96,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                if (_portrait != null) const SizedBox(width: 16),
                _Swatch('털', colors.main),
                _Swatch('배·발', colors.second),
                _Swatch('무늬', colors.marking),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '어떤 모양이 가장 닮았나요?',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ShapePicker(
              colors: colors,
              selected: _shape,
              onSelect: (id) {
                Telemetry.track('shape_pick', {'shape': id});
                setState(() => _shape = id);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _namePage() {
    return _Page(
      title: '이름을 지어 주세요',
      subtitle: '아기부터 키우면 2주쯤 돌보며 자라요. 다 자란 모습으로 만나도 좋아요.',
      back: () => _go(0),
      next: _name.text.trim().isEmpty ? null : () => _go(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            maxLength: 8,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) _go(2);
            },
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PetStage>(
            segments: const [
              ButtonSegment(value: PetStage.puppy, label: Text('아기부터 키우기')),
              ButtonSegment(value: PetStage.adult, label: Text('지금 모습 그대로')),
            ],
            selected: {_stage},
            onSelectionChanged: (s) => setState(() => _stage = s.first),
          ),
          if (_colors case final colors?) ...[
            const SizedBox(height: 28),
            _AdoptionPortrait(
              colors: colors,
              shape: _shape,
              stage: _stage,
              name: _name.text.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placePage() {
    return _Page(
      title: '어디에 살아요?',
      subtitle: '동네를 알면 비 오는 날 창밖을 보고, 더운 날 늘어져 있어요. 건너뛰어도 돼요.',
      back: _creating || _createdPet != null ? null : () => _go(1),
      next: _creating ? null : _create,
      nextLabel: _creating ? '만드는 중…' : (_chosen == null ? '건너뛰고 시작' : '시작하기'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _place,
                  enabled: !_creating && _createdPet == null,
                  onChanged: (_) => _searchChanged(),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: '동네 이름',
                    hintText: '예: 서울, 관악구, 수원',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _searching || _creating || _createdPet != null
                    ? null
                    : _search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _places)
            ListTile(
              dense: true,
              title: Text(p.label),
              trailing: _chosen == p ? const Icon(Icons.check) : null,
              onTap: _creating || _createdPet != null
                  ? null
                  : () => setState(() => _chosen = p),
            ),
          if (_chosen != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '선택: ${_chosen!.label}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '나중에 설정에서도 넣을 수 있어요. 전국 시·군·구 목록 © OpenStreetMap 기여자',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('아침·저녁 알림 받기'),
            subtitle: const Text('아침에는 일기, 저녁에는 함께할 시간을 알려요.'),
            value: _dailyReminders,
            onChanged: _creating || _createdPet != null
                ? null
                : (value) => setState(() => _dailyReminders = value ?? false),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.back,
    this.next,
    this.nextLabel = '다음',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? footer;
  final VoidCallback? back;
  final VoidCallback? next;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: C3Text.title),
                ),
                const SizedBox(height: 8),
                Text(keepWords(subtitle), style: C3Text.body),
                const SizedBox(height: 22),
                child,
                if (footer != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    keepWords(footer!),
                    style: C3Text.body.copyWith(
                      fontSize: 13,
                      color: C3Colors.ink2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              if (back != null)
                TextButton(onPressed: back, child: const Text('이전')),
              const Spacer(),
              FilledButton(onPressed: next, child: Text(nextLabel)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdoptionPortrait extends StatelessWidget {
  const _AdoptionPortrait({
    required this.colors,
    required this.shape,
    required this.stage,
    required this.name,
  });

  final PetColors colors;
  final String shape;
  final PetStage stage;
  final String name;

  @override
  Widget build(BuildContext context) {
    final age = stage == PetStage.puppy ? '아기 강아지' : '다 자란 강아지';
    return Center(
      child: SizedBox(
        width: 268,
        height: 196,
        child: Semantics(
          image: true,
          excludeSemantics: true,
          label: '${name.isEmpty ? age : '$name, $age'} 모습 미리 보기',
          child: Polaroid(
            caption: name.isEmpty ? '이름을 기다리는 중' : name,
            captionRight: age,
            child: CustomPaint(
              painter: const _PortraitRoom(),
              child: Align(
                alignment: const Alignment(0, 0.65),
                child: PetSpritePreview(
                  shape: shape,
                  colors: colors,
                  stage: stage,
                  dimension: 128,
                  sitting: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitRoom extends CustomPainter {
  const _PortraitRoom();

  @override
  void paint(Canvas canvas, Size size) {
    paintRoomBackdrop(
      canvas,
      size,
      floorY: size.height * 0.62,
      rug: Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.84),
        width: size.width * 0.72,
        height: 34,
      ),
    );
  }

  @override
  bool shouldRepaint(_PortraitRoom old) => false;
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final int color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(color),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2B1D16)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
