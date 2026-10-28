import 'package:flutter/material.dart';

import '../pet/checkup.dart';
import '../pet/pet_rules.dart';
import 'c3/c3_theme.dart';

/// 건강 수첩 한 장. 의사 말이나 소견 없이 숫자만 담는다.
class CheckupCard extends StatelessWidget {
  const CheckupCard({super.key, required this.record});

  final CheckupRecord record;

  @override
  Widget build(BuildContext context) {
    final at = record.at;
    // 검진 가능일은 하루 시작(새벽 5시) 기준이라 날짜도 그 기준으로 센다.
    final next = petDate(at).add(const Duration(days: checkupEvery));
    final rows = [
      ('날짜', '${at.month}월 ${at.day}일'),
      (
        '몸무게',
        '${record.weight.toStringAsFixed(1)}kg'
            '${record.change == null ? '' : ' (${record.change})'}',
      ),
      ('체온', '${record.temperature.toStringAsFixed(1)}℃ 정상'),
      ('접종', record.shotLabel),
      ('다음 검진', '${next.month}월 ${next.day}일'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: C3Text.body.copyWith(color: C3Colors.ink2),
                  ),
                ),
                Expanded(child: Text(value, style: C3Text.label)),
              ],
            ),
          ),
      ],
    );
  }
}
