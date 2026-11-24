import 'package:flutter/material.dart';

import '../data/database.dart';
import '../pet/pet_controller.dart';
import '../pet/walk_log.dart';
import 'c3/c3_theme.dart';
import 'c3/paper.dart';
import 'c3/sticker_card.dart';
import 'walk_card.dart';

class WalkJournal extends StatefulWidget {
  const WalkJournal({super.key, required this.db, required this.controller});

  static const routeName = 'walk-journal';
  final AppDatabase db;
  final PetController controller;

  @override
  State<WalkJournal> createState() => _WalkJournalState();
}

/// 이 펫에서 저장하지 못한 산책을 한꺼번에 다시 시도한다.
class WalkSaveNotice extends StatelessWidget {
  const WalkSaveNotice({super.key, required this.controller});
  final PetController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.unsavedWalkCount;
    if (count == 0) return const SizedBox.shrink();
    return Material(
      color: C3Colors.tapeYellow,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text('산책 기록 $count건을 저장하지 못했어요.', style: C3Text.body),
              ),
              TextButton(
                onPressed: controller.retryingWalks
                    ? null
                    : controller.retryWalkRecords,
                child: Text(controller.retryingWalks ? '저장 중…' : '다시 저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkJournalState extends State<WalkJournal> {
  static const _pageSize = 30;
  int _limit = _pageSize;
  late Stream<List<Event>> _walks = widget.db.watchWalks(_limit + 1);

  @override
  void didUpdateWidget(WalkJournal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.db != widget.db) {
      _limit = _pageSize;
      _walks = widget.db.watchWalks(_limit + 1);
    }
  }

  void _read({bool more = false}) => setState(() {
    if (more) _limit += _pageSize;
    _walks = widget.db.watchWalks(_limit + 1);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('산책 기록')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (_, _) => WalkSaveNotice(controller: widget.controller),
        ),
      ),
      body: PaperBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: StreamBuilder<List<Event>>(
                key: ValueKey(widget.db),
                stream: _walks,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _read,
                        child: const Text('산책 기록을 불러오지 못했어요. 다시 읽기'),
                      ),
                    );
                  }
                  final rows = snapshot.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (rows.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          '아직 함께 다녀온 산책이 없어요.\n산책을 마치고 집에 오면 여기에 남아요.',
                          textAlign: TextAlign.center,
                          style: C3Text.body,
                        ),
                      ),
                    );
                  }
                  final more = rows.length > _limit;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    itemCount: more ? _limit + 1 : rows.length,
                    itemBuilder: (context, i) {
                      if (i == _limit) {
                        return TextButton(
                          onPressed: () => _read(more: true),
                          child: const Text('이전 산책 더 보기'),
                        );
                      }
                      final event = rows[i];
                      final walk = decodeWalkMap(event.walkMap);
                      // 오래된 기록은 종료 시각과 원래 문장만 남아 있다.
                      final at = walk?.startedAt ?? event.at;
                      final time =
                          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        key: ValueKey(event.id),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: StickerCard(
                          tape: i == 0 ? C3Colors.tapeMint : null,
                          padding: const EdgeInsets.fromLTRB(16, 18, 12, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${at.year}년 ${at.month}월 ${at.day}일 · $time ${walk == null ? '귀가' : '출발'}',
                                style: C3Text.label.copyWith(
                                  color: C3Colors.ink2,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                walk == null
                                    ? event.detail
                                    : '${walk.minutes}분 산책 · ${walkStepLabel(walk.steps, walk.coverage)}',
                                style: C3Text.pet.copyWith(fontSize: 21),
                              ),
                              if (walk != null && walk.spots.isNotEmpty)
                                Text(
                                  '${walk.spots.first.name}에서 한참 킁킁댔어요',
                                  style: C3Text.body.copyWith(
                                    fontSize: 14,
                                    color: C3Colors.ink2,
                                  ),
                                ),
                              if (walk != null) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      size: 19,
                                    ),
                                    label: const Text('산책 지도 보기'),
                                    onPressed: () => showWalkCard(
                                      context,
                                      name: widget.controller.pet.name,
                                      startedAt: walk.startedAt,
                                      minutes: walk.minutes,
                                      steps: walk.steps,
                                      coverage: walk.coverage,
                                      finds: walk.finds,
                                      spots: walk.spots,
                                    ),
                                  ),
                                ),
                              ],
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
