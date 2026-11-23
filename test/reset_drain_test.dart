import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

class _HeldSaveDb extends AppDatabase {
  _HeldSaveDb() : super(NativeDatabase.memory());
  Completer<void>? gate;
  bool failSave = false;

  @override
  Future<void> savePetState(Pet pet) async {
    await gate?.future;
    if (failSave) throw StateError('synthetic save failure');
    await super.savePetState(pet);
  }
}

class _HeldDiaryDb extends AppDatabase {
  _HeldDiaryDb() : super(NativeDatabase.memory());
  final gate = Completer<void>();
  final started = Completer<void>();

  @override
  Future<bool> hasDiary(String day) async {
    if (!started.isCompleted) started.complete();
    await gate.future;
    return super.hasDiary(day);
  }
}

void main() {
  final now = DateTime(2026, 10, 28, 12);

  Future<Pet> create(AppDatabase db) => db.createPet(
    name: '검사펫',
    stage: PetStage.adult,
    furMain: 1,
    furSecond: 2,
    marking: 3,
    now: now,
  );

  test('두 번 깨운 뒤 초기화도 먼저 시작한 걸음 수집을 기다린다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final pet = await create(db);
    final stepGate = Completer<int?>();
    final started = Completer<void>();
    final c = PetController(
      db,
      pet,
      clock: () => now,
      readStepTotal: () {
        if (!started.isCompleted) started.complete();
        return stepGate.future;
      },
    );
    addTearDown(() async {
      if (!stepGate.isCompleted) stepGate.complete(null);
      await c.settled;
      c.dispose();
      await db.close();
    });
    c.wake();
    await started.future;
    c.wake();
    await c.collected;
    var drained = false;
    final reset = c.prepareReset().then((_) => drained = true);
    await pumpEventQueue();
    final drainedEarly = drained;
    stepGate.complete(500);
    await reset;
    await db.resetAll();
    await pumpEventQueue();
    expect(drainedEarly, isFalse);
    expect(await db.loadPet(), isNull);
    expect(await db.allCarried(), isEmpty);
    expect(await db.eventsOn(now), isEmpty);
  });

  test('SQL 큐에 들어오기 전 대기 중인 저장도 초기화 전에 끝낸다', () async {
    final db = _HeldSaveDb();
    final pet = await create(db);
    final c = PetController(db, pet, clock: () => now);
    db.gate = Completer<void>();
    addTearDown(() async {
      if (!db.gate!.isCompleted) db.gate!.complete();
      await c.settled;
      c.dispose();
      await db.close();
    });
    c.sleepApp();
    var drained = false;
    final reset = c.prepareReset().then((_) => drained = true);
    await pumpEventQueue();
    final drainedEarly = drained;
    db.gate!.complete();
    await reset;
    await db.resetAll();
    await pumpEventQueue();
    expect(drainedEarly, isFalse);
    expect(await db.loadPet(), isNull);
  });

  test('초기화 실패 뒤에도 이미 시작한 지난 일기 보충을 빠뜨리지 않는다', () async {
    final db = _HeldDiaryDb();
    final pet = await create(db);
    final yesterday = now.subtract(const Duration(days: 1));
    await db.addEvent('feed', '합성 밥 기록', yesterday);
    final c = PetController(db, pet, clock: () => now);
    addTearDown(() async {
      if (!db.gate.isCompleted) db.gate.complete();
      await c.settled;
      c.dispose();
      await db.close();
    });
    c.wake();
    await db.started.future;
    final drain = c.prepareReset();
    db.gate.complete();
    await drain;
    await db.customStatement(
      "CREATE TRIGGER reject_reset BEFORE DELETE ON pets BEGIN SELECT RAISE(ABORT, 'synthetic reset failure'); END",
    );
    await expectLater(db.resetAll(), throwsA(anything));
    c.cancelReset();
    c.wake();
    await c.settled;
    expect(
      (await db.allDiaries()).map((d) => d.day),
      contains(dayKey(yesterday)),
    );
  });

  test('해제된 펫의 늦은 걸음 콜백은 오류나 상태 변경을 만들지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final pet = await create(db);
    final c = PetController(db, pet, clock: () => now);
    addTearDown(db.close);
    c.dispose();
    expect(() => c.updateWalkSteps(20), returnsNormally);
    expect(c.walkSteps, 0);
  });

  test('초기화용 완료 추적이 평소 백그라운드 저장 오류를 숨기지 않는다', () async {
    final db = _HeldSaveDb();
    final pet = await create(db);
    final c = PetController(db, pet, clock: () => now);
    addTearDown(() async {
      await c.settled;
      c.dispose();
      await db.close();
    });
    final errors = <Object>[];
    await runZonedGuarded(() async {
      db.failSave = true;
      c.sleepApp();
      await c.settled;
      await pumpEventQueue();
    }, (error, stack) => errors.add(error));
    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
  });
}
