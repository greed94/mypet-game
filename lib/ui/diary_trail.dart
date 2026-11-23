import 'package:flutter/material.dart';

import '../data/database.dart';
import 'c3/c3_theme.dart';
import 'c3/pixel_icon.dart';

/// 사용자가 실제로 한 돌봄과 게임 안에서 일어난 이정표만 날짜별로 보여 준다.
const _activities = <String, (String, String)>{
  'first_meeting': ('heart', '처음 만남'),
  'feed': ('bowl', '밥 먹기'),
  'pet': ('palm', '쓰다듬기'),
  'play': ('ball', '공 물어오기'),
  'cuddle': ('heart', '손길 나누기'),
  'walk': ('tree', '산책에서 귀가'),
  'treat': ('bone', '간식 건네기'),
  'grow': ('sparkle', '어른 강아지가 된 날'),
};

typedef _Page = ({List<({DateTime at, String kind})> rows, int limit});

typedef DiaryTrailPosition = ({bool expanded, int limit});

class DiaryTrail extends StatefulWidget {
  const DiaryTrail({
    super.key,
    required this.db,
    required this.day,
    required this.visible,
    this.open = false,
    this.position,
    this.onPositionChanged,
  });

  final AppDatabase db;
  final DateTime day;
  final bool visible;
  final bool open;
  final DiaryTrailPosition? position;
  final ValueChanged<DiaryTrailPosition>? onPositionChanged;

  @override
  State<DiaryTrail> createState() => _DiaryTrailState();
}

class _DiaryTrailState extends State<DiaryTrail> {
  late bool _expanded = widget.position?.expanded ?? widget.open;
  static const _pageSize = 5;
  late int _limit = widget.position?.limit ?? _pageSize;
  Stream<_Page>? _stream;
  _Page? _lastPage;

  void _read() {
    final limit = _limit;
    _stream = widget.visible && _expanded
        ? widget.db
              .watchDiaryActions(widget.day, _activities.keys, limit + 1)
              .map((rows) => (rows: rows, limit: limit))
        : null;
  }

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant DiaryTrail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day || oldWidget.db != widget.db) {
      _expanded = widget.position?.expanded ?? widget.open;
      _lastPage = null;
      _limit = widget.position?.limit ?? _pageSize;
      _read();
    } else if (oldWidget.visible != widget.visible) {
      _read();
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = '${widget.day.year}년 ${widget.day.month}월 ${widget.day.day}일';
    final title = widget.open ? '오늘의 발자국' : '그날의 발자국';
    final retry = TextButton(
      onPressed: () => setState(_read),
      child: Text('발자국 다시 읽기', semanticsLabel: '$date 발자국 다시 읽기'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            expanded: _expanded,
            child: TextButton(
              onPressed: () => setState(() {
                _expanded = !_expanded;
                if (!_expanded) _limit = _pageSize;
                widget.onPositionChanged?.call((
                  expanded: _expanded,
                  limit: _limit,
                ));
                _read();
              }),
              child: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const ExcludeSemantics(child: PixelIcon('paw_ink')),
                  Text(title, semanticsLabel: '$date $title'),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          StreamBuilder<_Page>(
            key: ValueKey((widget.db, widget.day)),
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) _lastPage = snapshot.data;
              final page = snapshot.data ?? _lastPage;
              if (page == null) {
                if (!widget.visible) return const SizedBox.shrink();
                if (snapshot.hasError) return retry;
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(),
                );
              }
              if (page.rows.isEmpty) {
                if (snapshot.hasError) return retry;
                return Text('이날은 아직 돌봄 발자국이 없어요.', style: C3Text.body);
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: C3Colors.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C3Colors.dot),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final row in page.rows.take(page.limit))
                        _activityRow(row.at, row.kind),
                      if (snapshot.hasError)
                        retry
                      else if (page.rows.length > page.limit)
                        TextButton(
                          onPressed: () => setState(() {
                            if (_limit == page.limit) {
                              _limit += _pageSize;
                              widget.onPositionChanged?.call((
                                expanded: _expanded,
                                limit: _limit,
                              ));
                              _read();
                            }
                          }),
                          child: Text(
                            '발자국 더 보기',
                            semanticsLabel: '$date 발자국 더 보기',
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _activityRow(DateTime at, String kind) {
    final activity = _activities[kind]!;
    final nextDay = at.day != widget.day.day;
    final clock =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ExcludeSemantics(child: PixelIcon(activity.$1)),
          Text(
            nextDay ? '다음 날 $clock' : clock,
            style: C3Text.label.copyWith(fontSize: 14, color: C3Colors.ink2),
          ),
          Text(activity.$2, style: C3Text.body),
        ],
      ),
    );
  }
}
