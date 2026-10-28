import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

/// 배운 날 칸(v20)이 생기기 전에 배운 개인기는 일기 재료에서 배운 날을 찾아 채운다.
void main() {
  test('그 개인기를 배운 줄 중 가장 이른 날(새벽은 전날)', () {
    final lines = [
      (at: DateTime(2026, 10, 2, 10), detail: "주인이 가르쳐 준 '앉아'를 처음으로 해냈다"),
      (at: DateTime(2026, 10, 1, 3), detail: "유치원에서 '앉아'를 배워 왔다"),
      (at: DateTime(2026, 9, 30, 9), detail: "주인 앞에서 '앉아'를 해 보였다"),
      (at: DateTime(2026, 9, 29, 9), detail: '내 이름이 콩이인 걸 알았다'),
      (at: DateTime(2026, 9, 28, 9), detail: '패드에서 쉬하는 걸 배웠다'),
    ];
    expect(learnedDayFromLines(Trick.sit, lines), '2026-09-30');
    expect(learnedDayFromLines(Trick.name, lines), '2026-09-29');
    expect(learnedDayFromLines(Trick.potty, lines), '2026-09-28');
    expect(learnedDayFromLines(Trick.down, lines), isNull);
  });

  test('앱을 열면 배운 날이 빈 개인기에 날짜를 채우고, 못 찾으면 그대로 둔다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });
    final now = DateTime(2026, 10, 4, 14);
    final pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 6)),
    );
    await db.savePet(pet.copyWith(lastSeenAt: now));
    const old = TrickProgress(
      attempts: 6,
      successes: 5,
      days: 3,
      lastDay: '2026-10-03',
    );
    await db.saveTrick(Trick.sit, old);
    await db.saveTrick(Trick.down, old);
    await db.saveTrick(
      Trick.spin,
      const TrickProgress(attempts: 2, successes: 1, days: 1),
    );
    await db.addEvent(
      'trick',
      "주인이 가르쳐 준 '앉아'를 처음으로 해냈다",
      DateTime(2026, 10, 1, 20),
    );
    final c = PetController(
      db,
      (await db.loadPet())!,
      random: Random(1),
      clock: () => now,
    );
    c.wake();
    await c.collected;
    await pumpEventQueue(times: 20);
    expect(c.tricks[Trick.sit]!.learnedDay, '2026-10-01');
    expect(c.tricks[Trick.sit]!.attempts, old.attempts);
    expect(c.tricks[Trick.down]!.learnedDay, isNull);
    expect(c.tricks[Trick.spin]!.learnedDay, isNull);
    expect((await db.loadTricks())[Trick.sit]!.learnedDay, '2026-10-01');
  });

  test('날짜 채우기가 실패해도 개인기는 읽히고 시킬 수 있다', () async {
    final db = _BrokenEvents(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });
    final now = DateTime(2026, 10, 4, 14);
    final pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 6)),
    );
    await db.savePet(pet.copyWith(lastSeenAt: now));
    await db.saveTrick(
      Trick.sit,
      const TrickProgress(attempts: 6, successes: 5, days: 3, lastDay: 'x'),
    );
    final c = PetController(
      db,
      (await db.loadPet())!,
      random: Random(1),
      clock: () => now,
    );
    c.wake();
    await c.collected;
    expect(c.tricks[Trick.sit]!.successes, 5);
    expect(c.tricks[Trick.sit]!.learnedDay, isNull);
    c.stats = c.stats.copyWith(energy: 90);
    c.step = const PetStep(Behavior.idle, 3);
    c.command(Trick.sit);
    expect(c.tricks[Trick.sit]!.attempts, 7);
  });
}

/// 일기 재료 읽기가 늘 실패하는 DB.
class _BrokenEvents extends AppDatabase {
  _BrokenEvents(super.e);

  @override
  Future<List<Event>> eventsOfKind(String kind) =>
      Future.error(StateError('읽기 실패'));
}
