import 'package:flutter/material.dart';

import '../data/database.dart';
import '../pet/pet_controller.dart';
import 'c3/c3_theme.dart';
import 'c3/paper.dart';
import 'c3/pixel_icon.dart';
import 'c3/sticker_card.dart';
import 'keep_words.dart';

class MemoryNotebook extends StatefulWidget {
  const MemoryNotebook({super.key, required this.controller});

  final PetController controller;

  @override
  State<MemoryNotebook> createState() => _MemoryNotebookState();
}

class _MemoryNotebookState extends State<MemoryNotebook> {
  static const _pageSize = 30;
  int _limit = _pageSize;
  late Stream<List<Memory>> _entries = widget.controller.watchMemoryNotebook(
    _limit + 1,
  );
  bool _changing = false;

  @override
  void didUpdateWidget(MemoryNotebook old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _limit = _pageSize;
      _entries = widget.controller.watchMemoryNotebook(_limit + 1);
      _changing = false;
    }
  }

  bool _current(PetController c) =>
      mounted &&
      widget.controller == c &&
      !c.isDisposed &&
      !c.isResetting &&
      ModalRoute.isCurrentOf(context) != false;

  void _read({bool more = false}) {
    setState(() {
      if (more) _limit += _pageSize;
      _entries = widget.controller.watchMemoryNotebook(_limit + 1);
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _change(Future<void> Function(PetController) action) async {
    final c = widget.controller;
    if (_changing || !_current(c)) return;
    setState(() => _changing = true);
    try {
      await action(c);
    } catch (_) {
      if (_current(c)) _message('기억을 바꾸지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted && widget.controller == c) setState(() => _changing = false);
    }
  }

  Future<void> _pin(Memory memory) => _change((c) async {
    final result = await c.setMemoryPinned(memory.id, !memory.pinned);
    if (!_current(c)) return;
    if (result == MemoryPinResult.full) {
      _message('기억은 $conversationMemoryLimit개까지 고정할 수 있어요. 먼저 하나를 풀어 주세요.');
    } else if (result == MemoryPinResult.missing) {
      _message('수첩에서 이미 지운 기억이에요.');
    }
  });

  Future<void> _forget(Memory memory) => _change((c) async {
    final yes = await showC3Dialog<bool>(
      context,
      title: '이 기억을 지울까요?',
      body: Text(
        keepWords('“${memory.content}”\n\n수첩에서 지우면 앞으로 대화에 참고할 기억에서도 빠져요.'),
      ),
      actions: [
        Builder(
          builder: (dialog) => TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('취소'),
          ),
        ),
        Builder(
          builder: (dialog) => FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('지우기'),
          ),
        ),
      ],
    );
    if (yes != true || !_current(c)) return;
    await c.forgetMemory(memory.id);
  });

  @override
  Widget build(BuildContext context) {
    final name = widget.controller.pet.name;
    return Scaffold(
      appBar: AppBar(title: const Text('기억 수첩')),
      body: PaperBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: StreamBuilder<List<Memory>>(
                key: ValueKey(widget.controller),
                stream: _entries,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _read,
                        child: const Text('기억을 불러오지 못했어요. 다시 읽기'),
                      ),
                    );
                  }
                  final rows = snap.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(26),
                        child: StickerCard(
                          tape: C3Colors.tapeMint,
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PixelIcon('book', scale: 3),
                              const SizedBox(height: 14),
                              Text('아직 적힌 기억이 없어요', style: C3Text.label),
                              const SizedBox(height: 8),
                              Text(
                                keepWords(
                                  '집에서 말을 걸어 보세요. AI가 대화에서 기억해 둔 이야기가 여기에 모여요.',
                                ),
                                textAlign: TextAlign.center,
                                style: C3Text.body,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final more = rows.length > _limit;
                  final count = more ? _limit : rows.length;
                  final pins = rows.where((m) => m.pinned).length;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: 1 + count + (more ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name의 기억',
                                style: C3Text.title.copyWith(fontSize: 26),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                keepWords(
                                  'AI가 지난 대화에서 기억해 둔 이야기예요. 다음 대화는 고정한 기억부터 최대 다섯 개를 참고해요. 남은 자리는 최근 기억으로 채워요.',
                                ),
                                style: C3Text.body,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '고정 $pins / $conversationMemoryLimit',
                                style: C3Text.label.copyWith(
                                  color: C3Colors.ink2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (i > count) {
                        return TextButton(
                          onPressed: () => _read(more: true),
                          child: const Text('이전 기억 더 보기'),
                        );
                      }
                      final memory = rows[i - 1];
                      final at = memory.createdAt;
                      return Padding(
                        key: ValueKey(memory.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StickerCard(
                          tape: memory.pinned ? C3Colors.tapePink : null,
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${memory.pinned ? '고정 · ' : ''}${at.year}년 ${at.month}월 ${at.day}일',
                                      style: C3Text.body.copyWith(
                                        fontSize: 13,
                                        color: C3Colors.ink2,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: memory.pinned ? '고정 해제' : '기억 고정',
                                    isSelected: memory.pinned,
                                    selectedIcon: const Icon(
                                      Icons.push_pin,
                                      color: C3Colors.stamp,
                                    ),
                                    icon: const Icon(Icons.push_pin_outlined),
                                    onPressed: _changing
                                        ? null
                                        : () => _pin(memory),
                                  ),
                                  IconButton(
                                    tooltip: '기억 지우기',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: _changing
                                        ? null
                                        : () => _forget(memory),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  keepWords(memory.content),
                                  style: C3Text.body.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
