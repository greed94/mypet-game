import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/walk_log.dart';

void main() {
  test('v32 산책 문장을 보존하고 새 산책의 원래 지도를 파일을 다시 열어 복원한다', () async {
    final dir = await Directory.systemTemp.createTemp('mypet_walk_journal_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/synthetic.sqlite');
    var now = DateTime(2026, 11, 24, 15, 2, 18, 472);
    var db = AppDatabase(NativeDatabase(file));
    await db.createPet(
      name: '솔이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    await db.addEvent(
      'walk',
      '주인이랑 13분 산책했다 (1100걸음)',
      now.subtract(const Duration(days: 1)),
    );
    await db.customStatement('DROP INDEX events_kind_at');
    await db.customStatement('ALTER TABLE events DROP COLUMN walk_map');
    await db.customStatement('PRAGMA user_version = 32');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final c = PetController(
      db,
      (await db.loadPet())!,
      clock: () => now,
      random: Random(3),
    );
    final start = now;
    expect(c.startWalk(), isTrue);
    c.updateWalkSteps(2140);
    c.walkSniffs = 2;
    now = now.add(const Duration(minutes: 23, seconds: 11));
    final result = c.endWalk();
    expect(c.endWalk().steps, 0);
    await c.settled;
    final balance = c.paws;
    c.dispose();
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.watchWalks(3).first;
    expect(rows, hasLength(2));
    expect(rows.last.detail, '주인이랑 13분 산책했다 (1100걸음)');
    expect(rows.last.walkMap, isNull);
    final actual = decodeWalkMap(rows.first.walkMap)!;
    expect(actual.steps, 2140);
    expect(actual.minutes, 23);
    expect(actual.finds, result.finds);
    expect(actual.startedAt, start);
    expect(actual.spots, result.spots);
    expect(walkPath(actual.startedAt), walkPath(result.startedAt));
    expect(
      (await db.eventsOn(now)).where((e) => e.kind == 'walk'),
      hasLength(1),
    );
    expect((await db.loadPet())!.paws, balance);
  });

  test('킁킁 자리 쓰기가 막히면 지도도 되돌리고, 재시도해도 산책과 발도장이 늘지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final start = DateTime(2026, 11, 24, 14);
    var now = start;
    final pet = await db.createPet(
      name: '보리',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    final c = PetController(db, pet, clock: () => now, random: Random(1));
    addTearDown(c.dispose);
    await db.customStatement(
      "CREATE TRIGGER walk_spot_full BEFORE INSERT ON events WHEN NEW.kind = 'walk_spot' BEGIN SELECT RAISE(ABORT, 'synthetic full'); END",
    );
    expect(c.startWalk(), isTrue);
    c.walkSniffs = 2;
    c.updateWalkSteps(450);
    now = now.add(const Duration(minutes: 8));
    c.endWalk();
    final record = c.lastWalkRecord!;
    expect(await record.saved, isFalse);
    expect(await db.eventsOfKind('walk'), isEmpty);
    expect(await db.eventsOfKind('walk_spot'), isEmpty);
    final balance = c.paws;
    await db.customStatement('DROP TRIGGER walk_spot_full');
    expect(await Future.wait([record.retry(), record.retry()]), [true, true]);
    expect(await record.retry(), isTrue);
    expect(await db.eventsOfKind('walk'), hasLength(1));
    expect(await db.eventsOfKind('walk_spot'), hasLength(1));
    expect(c.paws, balance);
    now = start;
    expect(c.startWalk(), isTrue);
    c.walkSniffs = 2;
    c.updateWalkSteps(450);
    now = now.add(const Duration(minutes: 8));
    c.endWalk();
    expect(await c.lastWalkRecord!.saved, isTrue);
    await c.settled;
    expect(await db.eventsOfKind('walk'), hasLength(2));
    expect(await db.eventsOfKind('walk_spot'), hasLength(1));
  });

  test('연속 두 산책의 발견물 쓰기가 막혀도 전부 다시 저장하고 물건을 정확히 한 번씩 가져온다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = DateTime(2026, 11, 24, 14);
    final pet = await db.createPet(
      name: '보리',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    final c = PetController(db, pet, clock: () => now, random: Random(5));
    addTearDown(c.dispose);
    await db.customStatement(
      "CREATE TRIGGER block_finds BEFORE INSERT ON carried WHEN NEW.source = 'walk' BEGIN SELECT RAISE(ABORT, 'synthetic full'); END",
    );
    var found = 0;
    for (var i = 0; i < 2; i++) {
      expect(c.startWalk(), isTrue);
      c.updateWalkSteps(1200);
      now = now.add(const Duration(minutes: 5));
      found += c.endWalk().finds;
      expect(await c.lastWalkRecord!.saved, isFalse);
    }
    expect(found, greaterThan(0));
    expect(c.unsavedWalkCount, 2);
    expect(await db.eventsOfKind('walk'), isEmpty);
    expect(await db.allCarried(), isEmpty);
    final paws = c.paws;
    await db.customStatement('DROP TRIGGER block_finds');
    expect(await c.retryWalkRecords(), isTrue);
    expect(await c.retryWalkRecords(), isTrue);
    expect(c.unsavedWalkCount, 0);
    expect(await db.eventsOfKind('walk'), hasLength(2));
    expect(await db.allCarried(), hasLength(found));
    expect(c.carried, hasLength(found));
    expect(c.paws, paws);
    await c.settled;
  });

  for (final feedFirst in [false, true]) {
    test('지도를 닫은 뒤 한 번만 발견물을 내밀고 새 식사를 시작하면 기다린다 ($feedFirst)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026, 11, 24, 14);
      final pet = await db.createPet(
        name: '보리',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 1)),
      );
      final c = PetController(db, pet, clock: () => now);
      addTearDown(c.dispose);
      expect(c.startWalk(), isTrue);
      c.updateWalkSteps(1200);
      now = now.add(const Duration(minutes: 5));
      c.endWalk();
      c.uiBusy = true;
      expect(await c.lastWalkRecord!.saved, isTrue);
      expect(c.step.behavior, isNot(Behavior.waitAtDoor));
      if (feedFirst) c.interact(Interaction.feed);
      final before = c.step;
      c.uiBusy = false;
      if (feedFirst) {
        expect(c.step, same(before));
      } else {
        expect(c.step.behavior, Behavior.waitAtDoor);
        final greeting = c.step;
        c.uiBusy = true;
        c.uiBusy = false;
        expect(c.step, same(greeting));
      }
      await c.settled;
    });
  }

  test('같은 초의 산책은 최신 기록 번호부터 제한해서 읽고 목록에는 다른 활동이 들어오지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final at = DateTime(2026, 11, 24, 14);
    for (var i = 0; i < 35; i++) {
      await db.addEvent('walk', '산책 $i', at);
      await db.addEvent('meal', '밥', at);
    }
    final page = await db.watchWalks(31).first;
    expect(page.length, 31);
    expect(page.first.detail, '산책 34');
    expect(page.last.detail, '산책 4');
    final plan = await db
        .customSelect(
          "EXPLAIN QUERY PLAN SELECT * FROM events WHERE kind = 'walk' ORDER BY at DESC,id DESC LIMIT 31",
        )
        .get();
    expect(
      plan.map((r) => r.read<String>('detail')).join(' '),
      contains('events_kind_at'),
    );
  });

  test('깨졌거나 더 새 형식인 지도는 기존 산책 문장을 계속 볼 수 있다', () {
    final start = DateTime(2026, 11, 24, 12);
    final valid = encodeWalkMap((
      startedAt: start,
      steps: 150,
      minutes: 4,
      finds: 0,
      spots: <WalkSpot>[],
    ));
    expect(decodeWalkMap(valid)?.steps, 150);
    for (final broken in [
      null,
      '',
      '{',
      '[]',
      '{"v":2}',
      jsonEncode({...jsonDecode(valid) as Map, 'steps': -1}),
      jsonEncode({...jsonDecode(valid) as Map, 'startMs': 9000000000000000000}),
      jsonEncode({
        ...jsonDecode(valid) as Map,
        'spots': [
          ['풀숲', 1.5],
        ],
      }),
    ]) {
      expect(decodeWalkMap(broken), isNull);
    }
  });
}
