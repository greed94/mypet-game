import 'package:flutter/material.dart';

import '../data/database.dart';
import '../pet/josa.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import 'c3/c3_theme.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';
import 'kinder_photo_card.dart';
import 'walk_journal.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.controller,
    required this.db,
    this.visible = true,
  });

  final PetController controller;
  final AppDatabase db;
  final bool visible;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late Future<(List<Diary>, Map<String, KinderPhotoRow>)> _diaries = _load();
  int _seenVersion = 0;
  bool _busy = false;
  int _loadGeneration = 0;
  (List<Diary>, Map<String, KinderPhotoRow>)? _lastLoaded;

  @override
  void initState() {
    super.initState();
    _seenVersion = widget.controller.diaryVersion;
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller &&
        oldWidget.db == widget.db) {
      return;
    }
    oldWidget.controller.removeListener(_onChange);
    widget.controller.addListener(_onChange);
    _seenVersion = widget.controller.diaryVersion;
    _lastLoaded = null;
    _busy = false;
    _diaries = _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (widget.controller.diaryVersion != _seenVersion) {
      _seenVersion = widget.controller.diaryVersion;
      _reload();
    }
  }

  Future<(List<Diary>, Map<String, KinderPhotoRow>)> _load() async {
    final generation = ++_loadGeneration;
    final db = widget.db;
    final data = (
      await db.allDiaries(),
      {for (final p in await db.allKinderPhotos()) p.day: p},
    );
    if (mounted && generation == _loadGeneration) _lastLoaded = data;
    return data;
  }

  void _reload() {
    setState(() {
      _diaries = _load();
    });
  }

  Widget _readFailure() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '일기를 불러오지 못했어요. 잠시 후 다시 읽어 주세요.',
          textAlign: TextAlign.center,
          style: C3Text.body,
        ),
        TextButton(onPressed: _reload, child: const Text('다시 읽기')),
      ],
    ),
  );

  /// 오늘 일기는 하루가 끝나야 쓰므로 여기서는 보여 주기만 하고 저장하지 않는다.
  Future<void> _writeToday() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = widget.controller;
    final db = widget.db;
    bool current() =>
        mounted && controller == widget.controller && db == widget.db;
    bool usable() =>
        current() &&
        widget.visible &&
        ModalRoute.of(context)?.isCurrent == true &&
        !controller.isResetting &&
        !controller.isDisposed;
    try {
      final now = controller.now();
      final diary = await controller.writeDiary(now, save: false);
      if (!mounted || !usable()) return;
      final photo = await db.kinderPhotoOn(dayKey(petDate(now)));
      if (!mounted || !usable()) return;
      if (diary == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘 아직 일기에 담을 일이 없어요.')));
        return;
      }
      await showC3Dialog<void>(
        context,
        title: '오늘 지금까지',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(keepWords(diary.text), style: C3Text.pet),
            if (photo != null) ...[
              const SizedBox(height: 16),
              Center(
                child: KinderPhotoCard(
                  photo: photo,
                  pet: widget.controller.pet,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              keepWords(
                '${diary.byAi ? 'AI가 ${widget.controller.pet.name}의 시점으로 쓴 글이에요. ' : ''}'
                '하루가 끝나면 오늘 일을 모두 담아 다시 써요.',
              ),
              style: C3Text.body.copyWith(color: C3Colors.ink2),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ),
        ],
      );
    } catch (_) {
      if (mounted && usable()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 일기를 불러오지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (current()) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.controller.pet.name;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$name의 일기',
                  style: C3Text.title.copyWith(fontSize: 26),
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _writeToday,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(_busy ? '쓰는 중…' : '오늘 미리 보기'),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.map_outlined, size: 19),
              label: const Text('산책 기록'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  settings: const RouteSettings(name: WalkJournal.routeName),
                  builder: (_) =>
                      WalkJournal(db: widget.db, controller: widget.controller),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<(List<Diary>, Map<String, KinderPhotoRow>)>(
            key: ValueKey((widget.controller, widget.db)),
            future: _diaries,
            builder: (context, snap) {
              final data = snap.data ?? _lastLoaded;
              final items = data?.$1 ?? const [];
              final photos = data?.$2 ?? const {};
              final failed =
                  snap.connectionState == ConnectionState.done && snap.hasError;
              if (snap.connectionState != ConnectionState.done &&
                  data == null) {
                return const Center(
                  child: CircularProgressIndicator(color: C3Colors.stamp),
                );
              }
              if (items.isEmpty && failed) return Center(child: _readFailure());
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '아직 일기가 없어요.\n하루가 지나면 ${josa(name, '이/가')} 어제 있었던 일을 적어요.',
                      textAlign: TextAlign.center,
                      style: C3Text.body.copyWith(color: C3Colors.ink2),
                    ),
                  ),
                );
              }
              final list = ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final d = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: StickerCard(
                      tape: _tapes[i % _tapes.length],
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _prettyDay(d.day),
                                style: C3Text.pet.copyWith(
                                  fontSize: 19,
                                  color: C3Colors.ink2,
                                ),
                              ),
                              if (d.byAi) ...[
                                Text(
                                  'AI',
                                  style: C3Text.label.copyWith(
                                    fontSize: 12,
                                    color: C3Colors.ink3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            keepWords(d.content),
                            style: C3Text.body.copyWith(height: 1.6),
                          ),
                          if (photos[d.day] case final photo?) ...[
                            const SizedBox(height: 18),
                            Center(
                              child: KinderPhotoCard(
                                photo: photo,
                                pet: widget.controller.pet,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
              return Column(
                children: [
                  if (failed) _readFailure(),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'AI 표시가 있는 일기는 AI가 $name의 시점으로 쓴 문장이에요',
            textAlign: TextAlign.center,
            style: C3Text.body.copyWith(fontSize: 12, color: C3Colors.ink3),
          ),
        ),
      ],
    );
  }

  static const _tapes = [
    C3Colors.tapeMint,
    C3Colors.tapePink,
    C3Colors.tapeSky,
    C3Colors.tapeYellow,
  ];
}

String _prettyDay(String key) {
  final parts = key.split('-').map(int.parse).toList();
  final t = DateTime(parts[0], parts[1], parts[2]);
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${t.month}월 ${t.day}일 ${days[t.weekday - 1]}요일';
}
