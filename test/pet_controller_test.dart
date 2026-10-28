import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

Future<Pet> makePet(AppDatabase db, DateTime at) => db.createPet(
  name: '콩이',
  stage: PetStage.puppy,
  furMain: 0xFFF8F1E6,
  furSecond: 0xFFFFFDF8,
  marking: 0xFF914F28,
  now: at,
);

void main() {
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 9, 25, 14);
  });

  // 앱을 열면 발견물 챙기기가 비동기로 돌아서, 끝나기 전에 DB를 닫지 않게 기다린다.
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> controllerAwayFor(Duration away) async {
    final pet = await makePet(db, now.subtract(away));
    return PetController(db, pet, random: Random(1), clock: () => now);
  }

  test('6시간 만에 켜면 달려와서 반기고 저장한다', () async {
    final c = await controllerAwayFor(const Duration(hours: 6));
    c.wake();
    expect(c.stats.hunger, closeTo(60, 0.01));

    // 반기는 모습은 성격과 그날에 따라 여러 가지(문 앞 대기, 킁킁, 우다다)지만 달려와서 반기는 건 같다.
    final seen = <Behavior>[c.step.behavior];
    for (var i = 0; i < 12 && c.step.behavior != Behavior.happy; i++) {
      if (c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      seen.add(c.step.behavior);
    }
    expect(seen, contains(Behavior.run));
    expect(c.step.behavior, Behavior.happy);

    await pumpEventQueue();
    final saved = await db.select(db.pets).getSingle();
    expect(saved.lastSeenAt, now);
    expect(saved.hunger, closeTo(60, 0.01));
  });

  test('쓰다듬기는 진행 중인 반김 순서를 끊고 바로 반응한다', () async {
    final c = await controllerAwayFor(const Duration(hours: 6));
    c.wake();
    c.interact(Interaction.pet);
    expect(c.step.behavior, Behavior.happy);
    for (var i = 0; i < 3; i++) {
      c.tick(1);
    }
    expect(c.step.behavior, isNot(Behavior.run));
  });

  test('켜져 있는 동안은 1분마다 상태가 진행된다', () async {
    final c = await controllerAwayFor(Duration.zero);
    c.wake();
    final before = c.stats.hunger;
    now = now.add(const Duration(minutes: 1));
    for (var i = 0; i < 60; i++) {
      c.tick(1);
    }
    expect(c.stats.hunger, greaterThan(before));
  });

  test('v1 DB는 새 열 기본값을 받으며 기존 펫을 유지한 채 v4로 올라간다', () async {
    await db.close();
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE pets (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
            'stage TEXT NOT NULL, fur_main INTEGER NOT NULL, fur_second INTEGER NOT NULL, '
            'accent INTEGER NOT NULL, born_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL, '
            'mood REAL NOT NULL, hunger REAL NOT NULL, energy REAL NOT NULL, affection REAL NOT NULL)',
          );
          raw.execute(
            "INSERT INTO pets VALUES (1, '콩이', 'puppy', 1, 2, 3, 0, 0, 50, 40, 30, 20)",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    final pet = (await db.loadPet())!;
    expect(pet.affection, 20);
    expect(pet.marking, 0xFF914F28);
    expect(pet.careScore, 0);
    expect(await db.allDiaries(), isEmpty);
  });

  test('백그라운드 복귀 직후의 큰 dt는 상태를 두 번 진행시키지 않는다', () async {
    final c = await controllerAwayFor(Duration.zero);
    c.wake();
    final before = c.stats.hunger;
    c.tick(3600);
    expect(c.stats.hunger, before);
  });
}
