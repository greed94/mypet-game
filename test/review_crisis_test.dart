import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

const crisisExamples = [
  '뒤지고 싶어',
  '디지고 싶다',
  '죽어야겠다',
  '내가 죽는 게 낫겠어',
  '내가 죽었으면 좋겠어',
  '살 이유가 없어',
  '사는 의미가 없어',
  '살아서 뭐해',
  '인생 끝내고 싶어',
  '사라져 버리고 싶어',
  '없어져 버리고 싶어',
  '죽어 버릴까',
  '손목 긋고 싶어',
  '번개탄 피울까',
  '목을 매고 싶어',
  'ㅈㄱㅅㄷ',
  'I want to die',
  'suicide',
  '그냥 죽을까',
  '다 끝내고 싶어',
  '나 이제 그냥 다 끝내고 싶어요',
  '내일 눈 안 떴으면 좋겠다',
  '사는 게 의미가 없어',
  '수면제 다 먹어버릴까',
  '수면제를 다 먹어 버릴까',
  'kms',
  'I wanna kms.',
  '살기..싫어',
  '죽고…싶다',
  '죽고\n싶어',
  '죽고\t싶어',
  '죽고ㅠㅠ싶어',
  '죽고ㅋㅋ싶다',
];

class _CountingBrain implements PetBrain {
  var calls = 0;
  @override
  String get label => 'synthetic';
  @override
  Future<PetDecision> decide(String system, String user) async {
    calls++;
    return const PetDecision(
      moodDelta: 0,
      affectionDelta: 0,
      action: PetAction.sit,
      thought: '곁에 있을게.',
    );
  }

  @override
  Future<String> writeText(String system, String user) async {
    calls++;
    return '합성 검사 일기.';
  }
}

void main() {
  test('리뷰에서 놓친 직접 위기 표현과 구분 문자를 감지한다', () {
    for (final text in crisisExamples) {
      expect(isCrisis(text), isTrue, reason: text);
    }
  });

  test('일상 과장·축구·일반 영어 낱말은 위기 표현이 아니다', () {
    for (final text in [
      '배고파 죽겠다',
      '피곤해 죽겠다',
      '웃겨 죽겠네',
      '죽도록 사랑해',
      '오늘 힘들었어',
      '자살골 넣었어',
      '살 이유가 생겼어',
      '사는 의미를 찾았어',
      '죽어도 좋아하는 노래야',
      '목을 매는 넥타이',
      'I want to diet',
      '숙제 끝내고 싶어',
      '나 이제 숙제 다 끝내고 싶어',
      '일 다 끝내고 싶어',
      '회사 그만두고 싶어',
      '내일 일찍 눈뜨기 싫어',
      '수면제를 처방대로 먹었어',
      'I walked five kms.',
      'AWS KMS key rotation',
      '서버 KMS 키 설정',
      'bookmarks and links',
      'kmstools',
    ]) {
      expect(isCrisis(text), isFalse, reason: text);
    }
  });

  test('새 위기 표현은 AI·기억·일기 재료에 보내지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 10, 22, 12);
    final pet = await db.createPet(
      name: '검사펫',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    final brain = _CountingBrain();
    final c = PetController(
      db,
      pet,
      brain: brain,
      systemPrompt: 'synthetic',
      random: Random(1),
      clock: () => now,
    );
    try {
      for (final text in crisisExamples) {
        expect(await c.talk(text), TalkOutcome.crisis, reason: text);
      }
      await c.settled;
      expect(brain.calls, 0);
      expect(await db.recentMemories(100), isEmpty);
      expect(await db.allDiaries(), isEmpty);
      expect(await db.customSelect('SELECT detail FROM events').get(), isEmpty);
    } finally {
      c.dispose();
      await c.settled;
      await db.close();
    }
  });
}
