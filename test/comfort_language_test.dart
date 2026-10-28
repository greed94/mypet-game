import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';

void main() {
  test('인사·요청·다른 부정은 지친 말의 부정이 아니다', () {
    for (final text in [
      '안녕 오늘 너무 힘들었어',
      '안아 줘 너무 지쳤어',
      '안 좋은 일 있어서 속상해',
      '회사에 가지 않았어 너무 우울해',
      '안방에 누웠어 피곤해',
      '힘들어 말하기도 싫어',
      '피곤해 말이 안 나와',
      '실수하지 마라고 혼나서 속상해',
    ]) {
      expect(needsComfort(text), isTrue, reason: text);
      expect(askingOrDenying(text), isFalse, reason: text);
    }
  });

  test('지친 말 자체를 부정하거나 펫에게 묻는 말은 그대로 거른다', () {
    for (final text in [
      '안 힘들어',
      '안힘들어',
      '피곤하지 않아',
      '슬프지 않아요',
      '우울하지 마',
      '슬퍼하지 마',
      '슬퍼하지 마세요',
      '우울하지 마요',
      '힘들지 마',
      '하나도 외롭지 않아',
      '외로웠지?',
    ]) {
      expect(askingOrDenying(text), isTrue, reason: text);
    }
  });

  test('인사로 시작한 지친 말도 로컬 위로와 다음 선물로 이어진다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 10, 28, 12);
    final pet = await db.createPet(
      name: '검사펫',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    final c = PetController(db, pet, clock: () => now);
    try {
      await c.talk('안녕 오늘 너무 힘들었어');
      expect(c.bubble, isNull);
      expect(c.pet.comfortDue, isTrue);
      expect(c.step.behavior, Behavior.walk);
    } finally {
      await c.settled;
      c.dispose();
      await db.close();
    }
  });
}
