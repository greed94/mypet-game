import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/wish.dart';

final _met = DateTime(2026, 11, 20, 23, 40);
final _morning = DateTime(2026, 11, 21, 9);

Future<Pet> _adopt(AppDatabase db, {bool meeting = true}) async {
  final pet = await db.createPet(
    name: '보리',
    stage: PetStage.puppy,
    furMain: 1,
    furSecond: 2,
    marking: 3,
    now: _met,
  );
  if (meeting) {
    await db.queueFirstMeeting(_met);
    expect(await db.beginFirstMeeting(_met), isTrue);
  }
  return pet;
}

PetController _open(AppDatabase db, Pet pet, DateTime Function() now) {
  final c = PetController(db, pet, clock: now, random: Random(2));
  addTearDown(() async {
    if (!c.isDisposed) {
      await c.settled;
      c.dispose();
    }
  });
  return c;
}

class _HeldCareDb extends AppDatabase {
  _HeldCareDb() : super(NativeDatabase.memory());
  final started = Completer<void>();
  final release = Completer<void>();
  bool failOnce = false;
  int reads = 0;

  @override
  Future<Map<String, DateTime>> firstDayCareTimes(DateTime meetingDay) async {
    reads++;
    if (!started.isCompleted) started.complete();
    await release.future;
    if (failOnce) {
      failOnce = false;
      throw StateError('synthetic read failure');
    }
    return super.firstDayCareTimes(meetingDay);
  }
}

class _HeldInsertDb extends AppDatabase {
  _HeldInsertDb() : super(NativeDatabase.memory());
  final inserted = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> insertFirstRecognition(DateTime at, String detail) async {
    final added = await super.insertFirstRecognition(at, detail);
    if (!inserted.isCompleted) inserted.complete();
    await release.future;
    return added;
  }
}

void main() {
  for (final (care, recognition) in [
    ('feed', '킁… 어제 밥 주던 손 냄새다!'),
    ('play', '어제 공 던져 준 그 손이다!'),
  ]) {
    test('첫 재회 말풍선을 읽은 다음 오늘 소원을 말한다 · $care', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final pet = await _adopt(db);
      await db.addEvent(care, '첫날의 돌봄', _met);
      var now = _morning;
      final c = _open(db, pet, () => now)..wake();
      await c.settled;
      final wishLine = wishThought(c.openWish!);
      c.interact(Interaction.pet);
      await c.settled;
      expect(c.bubble, recognition);

      void advanceFrame() {
        now = now.add(const Duration(milliseconds: 250));
        c.tick(0.25);
      }

      for (var frame = 0; frame < 24; frame++) {
        advanceFrame();
        expect(c.bubble, recognition, reason: '${(frame + 1) * 250}ms');
      }
      for (var frame = 0; frame < 180 && c.bubble != wishLine; frame++) {
        advanceFrame();
      }
      expect(c.bubble, wishLine);
    });
  }

  test('실제 첫 끼는 DB를 닫은 뒤에도 첫 재회의 반응과 일기에 한 번 남는다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_first_return_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/fixture.sqlite');
    var now = _met;
    var db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
    });
    final first = _open(db, await _adopt(db), () => now);
    first.wake(firstMeeting: true);
    first.interact(Interaction.feed);
    first.sleepApp();
    await first.settled;
    first.dispose();
    await db.close();

    now = _morning;
    db = AppDatabase(NativeDatabase(file));
    final returned = _open(db, (await db.loadPet())!, () => now);
    returned.wake();
    await returned.settled;
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    returned.interact(Interaction.pet);
    await returned.settled;
    expect(returned.bubble, '킁… 어제 밥 주던 손 냄새다!');
    final event = (await db.eventsOfKind('first_recognition')).single;
    expect(event.at, now);
    expect(event.detail, contains('어제 밥을 준 주인 손'));
    final draft = await returned.writeDiary(now, save: false);
    expect(draft?.text, contains(event.detail));
    returned.sleepApp();
    await returned.settled;
    returned.dispose();
    await db.close();

    now = _morning.add(const Duration(minutes: 15));
    db = AppDatabase(NativeDatabase(file));
    final again = _open(db, (await db.loadPet())!, () => now)..wake();
    await again.settled;
    again.interact(Interaction.pet);
    await again.settled;
    expect(again.bubble, isNot('킁… 어제 밥 주던 손 냄새다!'));
    expect(await db.eventsOfKind('first_recognition'), hasLength(1));
    expect(await db.allDiaries(), hasLength(1));
  });

  for (final scenario in [
    '첫날',
    '세 번째 날',
    '입양 표식 없음',
    '어제는 첫 만남뿐',
    '어제 공놀이',
    '어제 산책',
    '어제 쓰다듬기',
  ]) {
    test('첫 재회는 실제 돌봄 이력을 따른다 · $scenario', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final pet = await _adopt(db, meeting: scenario != '입양 표식 없음');
      final now = switch (scenario) {
        '첫날' => _met,
        '세 번째 날' => DateTime(2026, 11, 22, 9),
        _ => _morning,
      };
      switch (scenario) {
        case '어제 공놀이':
          await db.addEvent('play', '주인이 던진 공을 물어 왔다', _met);
          await db.addEvent('feed', '주인이 밥을 줬다', _met);
        case '어제 산책':
          await db.addEvent('walk', '주인과 산책했다', _met);
        case '어제 쓰다듬기':
          await db.addEvent('pet', '주인이 쓰다듬어 줬다', _met);
        case '입양 표식 없음':
          await db.addEvent('feed', '주인이 밥을 줬다', _met);
      }
      // 오늘 먹은 밥은 어제의 사실이 아니다.
      await db.addEvent('feed', '주인이 밥을 줬다', _morning);
      final c = _open(db, pet, () => now)..wake();
      await c.settled;
      c.interact(Interaction.pet);
      await c.settled;
      final events = await db.eventsOfKind('first_recognition');
      final wanted = switch (scenario) {
        '어제 공놀이' => '어제 공 던져 준 그 손이다!',
        '어제 산책' => '어제 같이 산책한 주인 냄새다.',
        '어제 쓰다듬기' => '어제 쓰다듬던 그 손이다.',
        '어제는 첫 만남뿐' => '이 냄새, 어제 처음 맡아 봤어.',
        _ => null,
      };
      if (wanted == null) {
        expect(events, isEmpty);
      } else {
        expect(c.bubble, wanted);
        expect(events, hasLength(1));
      }
    });
  }

  test('입양을 저장한 뒤 다음 생활일에 처음 인사해도 실제 인사 다음 날 알아본다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await _adopt(db, meeting: false);
    await db.queueFirstMeeting(_met);
    expect(await db.beginFirstMeeting(_morning), isTrue);
    var now = _morning;
    final c = _open(db, pet, () => now)..wake(firstMeeting: true);
    c.interact(Interaction.pet);
    await c.settled;
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    now = DateTime(2026, 11, 22, 9);
    c.wake();
    await c.settled;
    c.interact(Interaction.pet);
    await c.settled;
    expect(c.bubble, '어제 쓰다듬던 그 손이다.');
    expect(await db.eventsOfKind('first_recognition'), hasLength(1));
  });

  test('같은 날짜 04시의 마지막 밥은 어제가 아니라 새벽으로 기억한다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pet = await _adopt(db);
    await db.addEvent('feed', '첫 밥', _met);
    await db.addEvent('feed', '다시 먹은 밥', DateTime(2026, 11, 21, 4, 52));
    final c = _open(db, pet, () => _morning)..wake();
    await c.settled;
    c.interact(Interaction.pet);
    await c.settled;
    expect(c.bubble, '킁… 새벽에 밥 주던 손 냄새다!');
    final event = (await db.eventsOfKind('first_recognition')).single;
    expect(event.detail, '새벽에 밥을 준 주인 손을 알아봤다');
  });

  for (final interruption in [
    '밥을 줌',
    '일기장을 엶',
    '일기장을 열었다 닫음',
    '권한 창을 열었다 닫음',
    '손길에서 1분이 지남',
    '화면을 끔',
    '날짜가 바뀜',
    '초기화를 시작함',
  ]) {
    test('이력을 읽는 중 $interruption · 지난 반응을 끼워 넣지 않는다', () async {
      final db = _HeldCareDb();
      addTearDown(db.close);
      final pet = await _adopt(db);
      var now = _morning;
      final c = _open(db, pet, () => now)..wake();
      await c.settled;
      c.interact(Interaction.pet);
      await db.started.future;
      switch (interruption) {
        case '밥을 줌':
          c.interact(Interaction.feed);
        case '일기장을 엶':
          c.roomHidden = true;
        case '일기장을 열었다 닫음':
          c.roomHidden = true;
          c.roomHidden = false;
        case '권한 창을 열었다 닫음':
          c.uiBusy = true;
          c.uiBusy = false;
        case '손길에서 1분이 지남':
          now = now.add(const Duration(minutes: 1));
          c.tick(1);
        case '화면을 끔':
          c.sleepApp();
        case '날짜가 바뀜':
          now = now.add(const Duration(days: 1));
        case '초기화를 시작함':
          unawaited(c.prepareReset());
      }
      db.release.complete();
      await c.settled;
      expect(await db.eventsOfKind('first_recognition'), isEmpty);
      expect(c.bubble, isNot('이 냄새, 어제 처음 맡아 봤어.'));
    });
  }

  test('쓰기 실패는 말풍선을 소비하지 않고 다시 열어 저장 가능해진 뒤 한 번 알아본다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_recognition_write_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/fixture.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
    });
    var now = _morning;
    final first = _open(db, await _adopt(db), () => now)..wake();
    await first.settled;
    await db.customStatement(
      """CREATE TRIGGER reject_recognition BEFORE INSERT ON events
      WHEN NEW.kind='first_recognition' BEGIN SELECT RAISE(ABORT, 'synthetic'); END""",
    );
    first.interact(Interaction.pet);
    await first.settled;
    expect(first.bubble, isNot('이 냄새, 어제 처음 맡아 봤어.'));
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    first.dispose();
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TRIGGER reject_recognition');
    now = now.add(const Duration(minutes: 1));
    final again = _open(db, (await db.loadPet())!, () => now)..wake();
    await again.settled;
    again.interact(Interaction.pet);
    await again.settled;
    expect(again.bubble, '이 냄새, 어제 처음 맡아 봤어.');
    expect(await db.eventsOfKind('first_recognition'), hasLength(1));
  });

  test('INSERT 대기 중 방을 떠나면 DELETE가 불가능해도 미표시 사건은 롤백한다', () async {
    final db = _HeldInsertDb();
    addTearDown(db.close);
    var now = _morning;
    final c = _open(db, await _adopt(db), () => now)..wake();
    await c.settled;
    await db.customStatement(
      """CREATE TRIGGER no_delete BEFORE DELETE ON events
      WHEN OLD.kind='first_recognition' BEGIN SELECT RAISE(ABORT, 'synthetic'); END""",
    );
    c.interact(Interaction.pet);
    await db.inserted.future;
    c.roomHidden = true;
    c.roomHidden = false;
    db.release.complete();
    await c.settled;
    expect(c.bubble, isNot('이 냄새, 어제 처음 맡아 봤어.'));
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    now = now.add(const Duration(seconds: 5));
    c.interact(Interaction.pet);
    await c.settled;
    expect(c.bubble, '이 냄새, 어제 처음 맡아 봤어.');
    expect(await db.eventsOfKind('first_recognition'), hasLength(1));
  });

  test('본문을 보여 준 뒤 COMMIT이 실패하면 다음 실행 준비 때 말은 반복하지 않고 기록을 복구한다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = _morning;
    final c = _open(db, await _adopt(db), () => now)..wake();
    await c.settled;
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement(
      'CREATE TABLE synthetic_parent (id INTEGER PRIMARY KEY)',
    );
    await db.customStatement(
      'CREATE TABLE synthetic_child (parent_id INTEGER REFERENCES synthetic_parent(id) DEFERRABLE INITIALLY DEFERRED)',
    );
    await db.customStatement(
      """CREATE TRIGGER fail_commit AFTER INSERT ON events
      WHEN NEW.kind='first_recognition' BEGIN INSERT INTO synthetic_child VALUES(1); END""",
    );
    c.interact(Interaction.pet);
    await c.settled;
    expect(c.bubble, '이 냄새, 어제 처음 맡아 봤어.');
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    await db.customStatement('DROP TRIGGER fail_commit');
    now = now.add(const Duration(seconds: 12));
    c.sleepApp();
    await c.settled;
    final event = (await db.eventsOfKind('first_recognition')).single;
    expect(event.at, _morning);
    c.wake();
    await c.settled;
    c.interact(Interaction.pet);
    await c.settled;
    expect(await db.eventsOfKind('first_recognition'), hasLength(1));
  });

  for (final fetch in [false, true]) {
    test('자정 양쪽에서 한 ${fetch ? '공 회수' : '쓰다듬기'}를 새벽으로 기억한다', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026, 11, 20, 23, 59, 56);
      final c = _open(db, await _adopt(db), () => now)
        ..wake(firstMeeting: true);
      await c.settled;
      if (fetch) {
        c.takeOutBall();
        c.arrived();
      }
      for (var i = 0; i < 2; i++) {
        if (fetch) {
          expect(c.throwBall(), isTrue);
          c.ballLanded();
          c.arrived();
          for (var j = 0; j < 12 && c.step.tag != StepTag.drop; j++) {
            if (c.step.behavior == Behavior.run) {
              c.arrived();
            } else {
              c.tick(0.5);
            }
          }
          expect(c.step.tag, StepTag.drop);
        } else {
          c.interact(Interaction.pet);
        }
        await c.settled;
        now = now.add(const Duration(seconds: 8));
      }
      expect(await db.eventsOfKind(fetch ? 'play' : 'pet'), hasLength(2));
      c.putBallAway();
      now = _morning;
      c.wake();
      await c.settled;
      c.interact(Interaction.pet);
      await c.settled;
      expect(c.bubble, fetch ? '새벽에 공 던져 준 그 손이다!' : '새벽에 쓰다듬던 그 손이다.');
    });
  }

  test('이력 조회가 실패해도 쓰다듬기는 살아 있고 다음 손길에서 다시 알아본다', () async {
    final db = _HeldCareDb()..failOnce = true;
    addTearDown(db.close);
    db.release.complete();
    var now = _morning;
    final c = _open(db, await _adopt(db), () => now)..wake();
    await c.settled;
    c.interact(Interaction.pet);
    await c.settled;
    expect(await db.eventsOfKind('first_recognition'), isEmpty);
    now = now.add(const Duration(seconds: 5));
    c.interact(Interaction.pet);
    await c.settled;
    expect(c.bubble, '이 냄새, 어제 처음 맡아 봤어.');
    expect(db.reads, 2);
  });
}
