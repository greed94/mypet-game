// 실제 PC 시계로 05시 전후에 두 번 실행한다. 앱 데이터 경로를 사용하지 않는다.
// flutter test tools/persona_sim/real_day_boundary_test.dart --dart-define=MYPET_BOUNDARY_STEP=seed
// flutter test tools/persona_sim/real_day_boundary_test.dart --dart-define=MYPET_BOUNDARY_STEP=reopen
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

void main() {
  const step = String.fromEnvironment('MYPET_BOUNDARY_STEP');
  test(
    '실제 새벽 5시를 사이에 두고 합성 펫의 식사가 다음 실행의 일기가 된다',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, dayStartHour);
      final cutoff = step == 'seed' && !now.isBefore(today)
          ? DateTime(now.year, now.month, now.day + 1, dayStartHour)
          : today;
      final folder = Directory(
        'build/portfolio/real-boundary-${dayKey(cutoff)}',
      )..createSync(recursive: true);
      final file = File('${folder.path}/synthetic-pet.sqlite');
      if (step == 'reopen') {
        expect(
          now.isBefore(cutoff),
          isFalse,
          reason: '실제 PC 시계로 05시가 지난 뒤 확인한다.',
        );
        expect(file.existsSync(), isTrue, reason: '경계 전에 생성한 합성 DB가 필요하다.');
      }
      final db = AppDatabase(NativeDatabase(file));
      PetController? c;
      try {
        var pet = await db.loadPet();
        if (step == 'seed' && pet == null) {
          pet = await db.transaction<Pet>(() async {
            final created = await db.createPet(
              name: '새벽검증',
              stage: PetStage.puppy,
              furMain: 1,
              furSecond: 2,
              marking: 3,
              now: now,
            );
            await db.queueFirstMeeting(now);
            return created;
          });
          c = PetController(db, pet);
          c.wake(firstMeeting: await db.beginFirstMeeting(DateTime.now()));
          c.interact(Interaction.feed);
          c.sleepApp();
          await c.settled;
        }
        expect(pet, isNotNull);
        final born = pet!.bornAt;
        expect(pet.name, '새벽검증');
        expect(born.isBefore(cutoff), isTrue);
        final day = dayKey(petDate(born));
        expect(
          day,
          dayKey(petDate(cutoff.subtract(const Duration(seconds: 1)))),
        );
        if (step == 'reopen') {
          expect(dayKey(petDate(now)), dayKey(cutoff));
          c = PetController(db, pet)..wake();
          await c.settled;
        }
        final records = await db.eventsOn(born);
        expect(records.where((e) => e.kind == 'first_meeting'), hasLength(1));
        expect(records.where((e) => e.kind == 'feed'), hasLength(1));
        final diaries = await db.allDiaries();
        if (step == 'reopen') {
          final entry = diaries.single;
          expect(entry.day, day);
          expect(entry.content, contains('처음으로 주인 냄새를 맡았다'));
          expect(entry.content, contains('밥을 줬다'));
          expect(entry.byAi, isFalse);
        } else {
          expect(diaries, isEmpty);
        }
        final result = {
          'step': step,
          'observedAt': now.toIso8601String(),
          'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
          'cutoff': cutoff.toIso8601String(),
          'bornAt': born.toIso8601String(),
          'petDay': day,
          'firstMeetings': 1,
          'meals': 1,
          'diaries': diaries.length,
        };
        await File('${folder.path}/observations.jsonl').writeAsString(
          '${jsonEncode(result)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } finally {
        await c?.settled;
        c?.dispose();
        await db.close();
      }
    },
    skip: const {'seed', 'reopen'}.contains(step)
        ? false
        : '실제 시각 검증 시 seed 또는 reopen을 지정한다.',
  );
}
