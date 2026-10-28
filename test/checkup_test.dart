import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/checkup.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/shapes.dart';

void main() {
  final born = DateTime(2026, 9, 1, 10);

  test('모든 모양 틀에 다 큰 몸무게가 있다', () {
    for (final s in dogShapes) {
      expect(adultWeightKg[s.id], isNotNull, reason: s.id);
    }
  });

  test('아기는 날이 갈수록 무거워지고 다 크면 다 큰 몸무게 언저리다', () {
    final early = weightKg('shiba', PetStage.puppy, born, born, 7);
    final later = weightKg(
      'shiba',
      PetStage.puppy,
      born,
      born.add(const Duration(days: 20)),
      7,
    );
    final adult = weightKg('shiba', PetStage.adult, born, born, 7);
    expect(later, greaterThan(early));
    expect(adult, greaterThan(later));
    expect(adult, inInclusiveRange(9.0 * 0.95, 9.0 * 1.05));
    expect(early, inInclusiveRange(9.0 * 0.3, 9.0 * 0.4));
    // 소수 한 자리.
    expect((adult * 10).roundToDouble(), adult * 10);
  });

  test('검진은 일주일에 한 번이고, 시계를 되돌려도 갇히지 않는다', () {
    final last = DateTime(2026, 10, 5, 10);
    expect(daysUntilCheckup(null, last), 0);
    expect(daysUntilCheckup(last, DateTime(2026, 10, 6, 10)), 6);
    expect(daysUntilCheckup(last, DateTime(2026, 10, 12, 4)), 1);
    expect(daysUntilCheckup(last, DateTime(2026, 10, 12, 6)), 0);
    expect(daysUntilCheckup(last, DateTime(2026, 10, 1)), 0);
  });

  test('건강 수첩: 아기는 접종 차수가 오르고 성체는 완료, 체온은 늘 정상 범위, 변화는 지난번과 비교', () {
    final pup = DateTime(2026, 10, 1, 10);
    final first = checkupFor(
      shape: 'maltese',
      stage: PetStage.puppy,
      bornAt: pup,
      now: DateTime(2026, 10, 2, 12),
      seed: 3,
      checkupsBefore: 0,
    );
    expect(first.shotLabel, '1/3차');
    expect(first.change, isNull);
    expect(first.temperature, inInclusiveRange(38.2, 38.8));

    final third = checkupFor(
      shape: 'maltese',
      stage: PetStage.puppy,
      bornAt: pup,
      now: DateTime(2026, 10, 12, 12),
      seed: 3,
      checkupsBefore: 5,
      previousWeight: first.weight,
    );
    expect(third.shotLabel, '3/3차');
    expect(third.change, startsWith('+'));

    final adult = checkupFor(
      shape: 'maltese',
      stage: PetStage.adult,
      bornAt: pup,
      now: DateTime(2026, 10, 19),
      seed: 3,
      checkupsBefore: 0,
      previousWeight: 99,
    );
    expect(adult.shotLabel, '완료');
    expect(adult.change, startsWith('-'));
  });
}
