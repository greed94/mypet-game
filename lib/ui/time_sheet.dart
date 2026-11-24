import 'package:flutter/material.dart';

import '../services/test_mode.dart';
import 'c3/c3_theme.dart';
import 'keep_words.dart';

/// 테스트 모드의 시간 보내기. 고른 만큼(앞으로만)을 돌려주고, 닫으면 null.
Future<Duration?> showTimeSheet(
  BuildContext context,
  DateTime Function() clock,
) {
  return showModalBottomSheet<Duration>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: C3Colors.card,
    showDragHandle: true,
    builder: (context) => TimeSheet(clock: clock),
  );
}

class TimeSheet extends StatelessWidget {
  const TimeSheet({super.key, required this.clock});

  final DateTime Function() clock;

  static const _spans = [
    ('+10분', Duration(minutes: 10)),
    ('+1시간', Duration(hours: 1)),
    ('+3시간', Duration(hours: 3)),
    ('+12시간', Duration(hours: 12)),
    ('+1일', Duration(days: 1)),
    ('+7일', Duration(days: 7)),
  ];

  /// 장소·리듬이 바뀌는 시각들: 유치원 문 열기, 오전, 낮잠, 맡기기 마감, 하원 버스, 잘 시간.
  static const _hours = [
    ('아침 7시', 7),
    ('오전 10시', 10),
    ('낮 1시', 13),
    ('오후 5시', 17),
    ('저녁 7시', 19),
    ('밤 11시', 23),
  ];

  @override
  Widget build(BuildContext context) {
    final now = clock();
    Widget chip(String label, Duration Function() duration) => ActionChip(
      label: Text(label),
      onPressed: () => Navigator.of(context).pop(duration()),
    );
    final day = const ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1];
    final mm = now.minute.toString().padLeft(2, '0');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('시간 보내기', style: C3Text.title),
            const SizedBox(height: 4),
            Text(
              keepWords(
                '시간표를 연 시각 ${now.month}월 ${now.day}일($day) ${now.hour}:$mm. '
                '펫의 하루는 새벽 5시에 시작해요.',
              ),
              style: C3Text.body.copyWith(color: C3Colors.ink2),
            ),
            const SizedBox(height: 14),
            chip('다음 날 아침 9시', () => untilNextPetMorning(clock())),
            const SizedBox(height: 14),
            Text('일정 시간 더하기', style: C3Text.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final (label, d) in _spans) chip(label, () => d)],
            ),
            const SizedBox(height: 14),
            Text('그 시각으로(지났으면 다음 날)', style: C3Text.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, h) in _hours)
                  chip(label, () => untilHour(clock(), h)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
