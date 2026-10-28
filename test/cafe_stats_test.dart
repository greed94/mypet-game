import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

/// 폰에서 카페 개인기 사이에 기분 41→35, 기운 98→89가 떨어진 걸 봤다(2026-10-03). 규칙엔 그런 비용이 없어야 한다.
void main() {
  test('카페에서 개인기를 몇 번 시켜도(실패 포함) 기분·기운이 뚝 떨어지지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 50);
      await db.close();
    });
    var now = DateTime(2026, 10, 5, 10);
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.puppy,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 5)),
    );
    pet = pet.copyWith(
      lastSeenAt: now,
      mood: 41,
      hunger: 100,
      energy: 98,
      affection: 35,
    );
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(7), clock: () => now);
    c.wake();
    await c.collected;
    expect(c.goToCafe(), isTrue);
    final mood0 = c.stats.mood, energy0 = c.stats.energy;
    for (var i = 0; i < 3; i++) {
      c.command(Trick.spin);
      for (var s = 0; s < 40; s++) {
        now = now.add(const Duration(seconds: 1));
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
      }
    }
    expect(c.stats.mood, greaterThanOrEqualTo(mood0 - 1));
    expect(c.stats.energy, greaterThanOrEqualTo(energy0 - 1));
  });
}
