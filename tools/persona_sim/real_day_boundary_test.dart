// 실제 PC 시계로 05시 전후에 두 번 실행한다. 앱 데이터 경로를 사용하지 않는다.
// flutter test tools/persona_sim/real_day_boundary_test.dart --dart-define=MYPET_BOUNDARY_STEP=seed
// flutter test tools/persona_sim/real_day_boundary_test.dart --dart-define=MYPET_BOUNDARY_STEP=reopen
// 깨어난 시간에 같은 합성 펫을 쓰다듬는 단계는 MYPET_BOUNDARY_STEP=touch.
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
      final returning = step == 'reopen' || step == 'touch';
      final today = DateTime(now.year, now.month, now.day, dayStartHour);
      final cutoff = step == 'seed' && !now.isBefore(today)
          ? DateTime(now.year, now.month, now.day + 1, dayStartHour)
          : today;
      final folder = Directory(
        'build/portfolio/real-boundary-${dayKey(cutoff)}',
      )..createSync(recursive: true);
      final file = File('${folder.path}/synthetic-pet.sqlite');
      if (returning) {
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
        String? touchThought;
        bool? seenBefore;
        if (returning) {
          expect(dayKey(petDate(now)), dayKey(cutoff));
          c = PetController(db, pet)..wake();
          await c.settled;
          if (step == 'touch') {
            expect(isNight(now), isFalse, reason: '실제 시계의 기상 시간에 확인한다.');
            seenBefore = (await db.eventsOfKind(
              'first_recognition',
            )).isNotEmpty;
            c.interact(Interaction.pet);
            await c.settled;
            final when = dayKey(born) == dayKey(now) ? '새벽에' : '어제';
            final memory = (await db.eventsOfKind('first_recognition')).single;
            expect(memory.detail, '$when 밥을 준 주인 손을 알아봤다');
            final expected = '킁… $when 밥 주던 손 냄새다!';
            expect(c.bubble, seenBefore ? isNot(expected) : equals(expected));
            touchThought = c.bubble;
          }
        }
        final records = await db.eventsOn(born);
        expect(records.where((e) => e.kind == 'first_meeting'), hasLength(1));
        expect(records.where((e) => e.kind == 'feed'), hasLength(1));
        final diaries = await db.allDiaries();
        if (returning) {
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
          if (step == 'touch') ...{
            'seenBeforeTouch': seenBefore,
            'firstRecognitions': (await db.eventsOfKind(
              'first_recognition',
            )).length,
            'touchThought': touchThought,
          },
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
    skip: const {'seed', 'reopen', 'touch'}.contains(step)
        ? false
        : '실제 시각 검증 시 seed, reopen 또는 touch를 지정한다.',
  );
}
