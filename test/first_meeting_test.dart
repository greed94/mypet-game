import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

void main() {
  test('첫 인사 뒤 화면을 끈 밤의 기운은 원래 수면 리듬으로 회복된다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = DateTime(2026, 11, 20, 23, 40);
    final pet = await db.createPet(
      name: '보리',
      stage: PetStage.puppy,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    final c = PetController(db, pet, clock: () => now);
    addTearDown(() async {
      await c.settled;
      c.dispose();
    });
    c.wake(firstMeeting: true);
    c.sleepApp();
    final before = c.stats.energy;
    now = now.add(const Duration(minutes: 10));
    c.wake();
    expect(c.stats.energy, closeTo(before + 2, 0.001));
    expect(c.nightNow, true);
  });

  for (final hour in [14, 23]) {
    test('새 펫과 $hour시에 인사하고 돌본 기록이 다음 날 일기로 남는다', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026, 11, 20, hour, 40);
      final firstDay = now;
      final pet = await db.createPet(
        name: '보리',
        stage: PetStage.puppy,
        furMain: 0xFFC58E56,
        furSecond: 0xFFFFE9CD,
        marking: 0xFF7D502B,
        now: now,
      );
      PetController open(Pet pet) {
        final controller = PetController(
          db,
          pet,
          random: Random(2),
          clock: () => now,
        );
        addTearDown(() async {
          if (!controller.isDisposed) {
            await controller.settled;
            controller.dispose();
          }
        });
        return controller;
      }

      final first = open(pet);
      await db.queueFirstMeeting(now);
      expect(
        first.wake(firstMeeting: await db.beginFirstMeeting(now)),
        Greeting.hello,
      );
      expect(first.petX, doorX);
      expect(first.step.behavior, Behavior.sniff);
      expect(first.nightNow, false);
      first
        ..tick(1)
        ..tick(1);
      expect(first.step.behavior, Behavior.walk);
      first.arrived();
      expect(first.step.behavior, Behavior.happy);
      first.interact(Interaction.feed);
      await first.settled;
      final preview = await first.writeDiary(now, save: false);
      expect(preview?.byAi, false);
      expect(preview?.text, contains('처음으로 주인 냄새를 맡았다'));
      expect(preview?.text, contains('밥을 줬다'));
      expect(await db.allDiaries(), isEmpty);

      now = now.add(const Duration(seconds: 89));
      expect(first.nightNow, false);
      now = now.add(const Duration(seconds: 1));
      expect(first.nightNow, hour == 23);
      first.wake();
      await first.settled;
      first.dispose();
      final again = open((await db.loadPet())!);
      expect(again.wake(), Greeting.none);
      expect(again.nightNow, hour == 23);
      await again.settled;
      expect(
        (await db.eventsOn(firstDay)).where((e) => e.kind == 'first_meeting'),
        hasLength(1),
      );
      now = DateTime(2026, 11, 21, 9);
      again.wake();
      await again.settled;
      final diary = (await db.allDiaries()).single;
      expect(diary.day, dayKey(petDate(firstDay)));
      expect(diary.content, contains('처음으로 주인 냄새를 맡았다'));
      expect(diary.content, contains('밥을 줬다'));
      expect(diary.byAi, false);
      again.dispose();
    });
  }
}
