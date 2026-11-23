import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/rhythm.dart';

/// 07:50에 일어나 00:40에 자는 주인을 닷새 배운 리듬.
OwnerRhythm midnightWorker() {
  var r = const OwnerRhythm();
  DateTime? last;
  for (var d = 5; d < 10; d++) {
    for (final (t, minutes) in [
      (DateTime(2026, 10, d, 7, 50), 1),
      (DateTime(2026, 10, d, 20, 30), 3),
      (DateTime(2026, 10, d + 1, 0, 30), 10),
    ]) {
      r = r.observeOpen(t, last);
      last = t.add(Duration(minutes: minutes));
    }
  }
  return r;
}

void main() {
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> open({
    Duration away = const Duration(hours: 1),
    String? rhythm,
  }) async {
    var pet = await db.loadPet();
    pet ??= await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(away),
    );
    await db.savePet(
      pet.copyWith(
        lastSeenAt: now.subtract(away),
        rhythm: rhythm == null ? const Value.absent() : Value(rhythm),
      ),
    );
    return PetController(
      db,
      (await db.loadPet())!,
      random: Random(1),
      clock: () => now,
    );
  }

  test('성격과 배운 리듬은 저장돼서 다시 켜도 같은 강아지다', () async {
    now = DateTime(2026, 10, 5, 9);
    final c = await open();
    c.wake();
    c.sleepApp();
    await pumpEventQueue();
    final saved = (await db.loadPet())!;
    expect(saved.activity, c.traits.activity);
    expect(saved.attachment, c.traits.attachment);
    expect(OwnerRhythm.fromJson(saved.rhythm).days, 1);
    now = DateTime(2026, 10, 6, 9);
    final again = PetController(db, saved, clock: () => now);
    expect(again.traits.activity, c.traits.activity);
    expect(again.traits.attachment, c.traits.attachment);
  });

  test('사진에서 색을 다시 뽑으면 저장되고 그림만 다시 읽는다', () async {
    now = DateTime(2026, 10, 5, 9);
    final c = await open();
    c.wake();
    final version = c.spriteVersion;
    await c.changeColors(
      const PetColors(
        main: 0xFFF5EEE1,
        second: 0xFFFFFFFF,
        marking: 0xFF9A5A32,
      ),
      portraitPath: '/tmp/portrait.png',
    );
    expect(c.spriteVersion, version + 1);
    await pumpEventQueue();
    final saved = (await db.loadPet())!;
    expect(saved.furMain, 0xFFF5EEE1);
    expect(saved.marking, 0xFF9A5A32);
    expect(saved.portraitPath, '/tmp/portrait.png');
  });

  test('잘 자라고 하면 그 밤엔 기본 밤(23시) 전이라도 다시 켰을 때 자고 있다', () async {
    now = DateTime(2026, 10, 5, 21);
    var c = await open();
    c.wake();
    await c.talk('잘 자');
    c.sleepApp();
    await pumpEventQueue();
    now = DateTime(2026, 10, 5, 21, 40);
    c = await open(away: const Duration(minutes: 40));
    expect(c.wake(), Greeting.none);
    expect(c.step.behavior, Behavior.sleep);
  });

  test('잘 자라는 말이 없으면 같은 때 다시 켜도 깨어 있어 반긴다', () async {
    now = DateTime(2026, 10, 5, 21, 40);
    final c = await open(away: const Duration(minutes: 40));
    expect(c.wake(), Greeting.hello);
  });

  test('자정형 주인의 강아지는 밤 11시 반에 깨어 있어 반기지만, 밤이라 크게 짖지는 않는다', () async {
    now = DateTime(2026, 10, 10, 23, 30);
    final c = await open(
      away: const Duration(hours: 6),
      rhythm: midnightWorker().toJson(),
    );
    final cues = <Cue>[];
    c.cues.listen(cues.add);
    expect(c.wake(), Greeting.big);
    for (var i = 0; i < 12 && c.step.behavior != Behavior.happy; i++) {
      c.step.behavior == Behavior.run ? c.arrived() : c.tick(1);
    }
    await pumpEventQueue();
    expect(cues, contains(Cue.yip));
    expect(cues, isNot(contains(Cue.bark)));
  });

  test('낮잠을 깨우면 몇 분은 다시 안 자고, 그 뒤엔 다시 존다', () async {
    now = DateTime(2026, 10, 5, 14);
    // 아기에 덜 활발한 성격이라 낮잠이 잦다.
    final pet = await db.createPet(
      name: '콩이',
      stage: PetStage.puppy,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(hours: 1)),
    );
    await db.savePet(
      pet.copyWith(activity: const Value(0.2), attachment: const Value(0.5)),
    );
    final c = PetController(
      db,
      (await db.loadPet())!,
      random: Random(3),
      clock: () => now,
    );
    c.wake();
    c.step = const PetStep(Behavior.sleep, 30);
    c.interact(Interaction.pet);
    for (var i = 0; i < 300; i++) {
      c.tick(10);
      expect(c.step.behavior, isNot(Behavior.sleep));
    }
    now = now.add(const Duration(minutes: 4));
    var napped = false;
    for (var i = 0; i < 300 && !napped; i++) {
      c.tick(10);
      napped = c.step.behavior == Behavior.sleep;
    }
    expect(napped, isTrue);
  });

  test('낮잠은 쓰다듬으면 깨서 반기고 산책도 가지만, 밤잠은 깨지 않는다', () async {
    now = DateTime(2026, 10, 5, 14);
    final c = await open();
    c.wake();
    c.step = const PetStep(Behavior.sleep, 30);
    final before = c.stats.affection;
    c.interact(Interaction.pet);
    expect(c.step.behavior, Behavior.happy);
    expect(c.stats.affection, greaterThan(before));
    c.step = const PetStep(Behavior.sleep, 30);
    expect(c.startWalk(), isTrue);

    now = DateTime(2026, 10, 6, 2);
    final night = await open(away: const Duration(hours: 2));
    night.wake();
    night.step = const PetStep(Behavior.sleep, 30);
    final was = night.stats.affection;
    night.interact(Interaction.pet);
    expect(night.step.behavior, isNot(Behavior.happy));
    expect(night.stats.affection, was);
  });
}
