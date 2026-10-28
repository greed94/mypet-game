import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/treats.dart';

/// 입맛 도감(아이디어 #4의 남은 칸): 먹여 본 간식과 반응(좋아·그냥·별로)이 쌓인다.
void main() {
  test('저장 모양을 오가고, 모르는 간식·반응은 건너뛴다', () {
    final tried = {'cheese_ball': Reaction.love, 'jerky': Reaction.meh};
    expect(parseTried(triedToCsv(tried)), tried);
    expect(parseTried('없는간식:love,pollack:모름,pollack:plain'), {
      'pollack': Reaction.plain,
    });
    expect(parseTried(null), isEmpty);
    expect(triedToCsv({}), isNull);
  });

  test('간식을 주면 그 반응이 도감에 남고, 앱을 다시 켜도 그대로다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });
    final now = DateTime(2026, 10, 6, 14);
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(
      lastSeenAt: now,
      affection: 50,
      pawMarks: const Value('hidden'),
      treatPouch: const Value('cheese_ball,jerky'),
    );
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    c.step = const PetStep(Behavior.idle, 3);
    expect(c.treatsTried, isEmpty);
    c.giveTreat();
    c.giveTreat();
    final want = {
      for (final id in ['cheese_ball', 'jerky'])
        id: reactionToTreat(
          treatById(id)!,
          c.pet.likeTaste,
          c.pet.dislikeTaste,
        ),
    };
    expect(c.treatsTried, want);
    await pumpEventQueue(times: 20);
    expect(parseTried((await db.loadPet())!.treatsTried), want);
  });
}

/// 간식 반응은 발견물과 같은 갈래 규칙이다(좋아하는 갈래면 좋아, 싫어하는 갈래면 별로).
Reaction reactionToTreat(Treat t, Taste? like, Taste? dislike) =>
    t.taste == like
    ? Reaction.love
    : t.taste == dislike
    ? Reaction.meh
    : Reaction.plain;
