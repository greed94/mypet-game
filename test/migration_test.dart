import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/friends.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';
import 'package:mypet/pet/tricks.dart';

void main() {
  // 유저 폰에는 v4 데이터가 있다. v5~v31을 한 번에 거쳐 올라가도 펫과 일기가 남아야 한다.
  test('v4 DB가 v31로 한 번에 올라가도 펫과 일기가 그대로 남는다', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE pets (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, stage TEXT NOT NULL, fur_main INTEGER NOT NULL,
  fur_second INTEGER NOT NULL, accent INTEGER NOT NULL,
  marking INTEGER NOT NULL DEFAULT 4287713064, born_at INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL, mood REAL NOT NULL, hunger REAL NOT NULL,
  energy REAL NOT NULL, affection REAL NOT NULL,
  care_score REAL NOT NULL DEFAULT 0, region_name TEXT NULL,
  latitude REAL NULL, longitude REAL NULL, portrait_path TEXT NULL)''');
          raw.execute(
            'CREATE TABLE memories (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'content TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          raw.execute(
            'CREATE TABLE events (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'kind TEXT NOT NULL, detail TEXT NOT NULL, at INTEGER NOT NULL)',
          );
          raw.execute(
            'CREATE TABLE diaries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
            'day TEXT NOT NULL UNIQUE, content TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO pets (name, stage, fur_main, fur_second, accent, born_at, "
            "last_seen_at, mood, hunger, energy, affection, care_score, region_name) "
            "VALUES ('콩이', 'adult', 1, 2, 3, 1758800000, 1758800000, 60, 30, 80, 40, 12, '서울')",
          );
          raw.execute(
            "INSERT INTO diaries (day, content, created_at) "
            "VALUES ('2026-09-25', '산책했다.', 1758800000)",
          );
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(db.close);

    final pet = (await db.loadPet())!;
    expect(pet.name, '콩이');
    expect(pet.careScore, 12);
    expect(pet.regionName, '서울');
    expect(pet.likeTaste, isNull);
    expect(pet.lastStepTotal, isNull);
    expect(pet.pocketCount, 0);
    expect(pet.comfortDue, isFalse);
    expect(pet.lastCrisisAt, isNull);
    // 모양을 고르기 전의 펫은 모두 파피용 그림이었다.
    expect(pet.shape, 'papillon');
    expect(pet.countDay, isNull);
    expect(pet.bondToday, 0);
    expect(pet.talksToday, 0);
    expect(pet.activity, isNull);
    expect(pet.rhythm, isNull);
    expect(pet.pottyAt, isNull);
    expect(pet.daycareFrom, isNull);
    expect(pet.treatPouch, isNull);
    expect(pet.checkups, 0);
    expect(pet.lastWeight, isNull);
    expect(pet.daycareLesson, isNull);
    expect(pet.daycareRecitalStats, isNull);
    expect(pet.recitalDays, isNull);
    expect(pet.wish, isNull);
    expect(pet.wishDone, isFalse);
    expect(pet.paws, 0);
    expect(pet.owned, isNull);
    expect(pet.touchX, isNull);
    expect(pet.quirk, isNull);
    expect(pet.doorNews, isNull);
    expect(pet.habit, isNull);
    expect(pet.treatsTried, isNull);
    expect(pet.treatShares, isNull);
    expect(await db.allKinderPhotos(), isEmpty);
    expect(await db.loadFriends(), isEmpty);
    expect(await db.loadKnownDogs(), isEmpty);
    expect((await db.allDiaries()).single.content, '산책했다.');
    // 예전 일기는 모두 AI가 썼다.
    expect((await db.allDiaries()).single.byAi, isTrue);

    await db.addFind('acorn', gift: false);
    await db.addCarried('pinecone', FindSource.pocket, DateTime(2026, 9, 26));
    await db.savePlacements({'floor1': 'acorn'});
    await db.savePet(pet.copyWith(pocketCount: 2));
    expect((await db.allFinds()).single.count, 1);
    expect((await db.allCarried()).single.itemId, 'pinecone');
    expect(await db.loadPlacements(), {'floor1': 'acorn'});
    expect((await db.loadPet())!.pocketCount, 2);
    await db.saveTrick(
      Trick.sit,
      const TrickProgress(
        attempts: 2,
        successes: 1,
        days: 1,
        lastDay: '2026-09-28',
      ),
    );
    expect((await db.loadTricks())[Trick.sit]?.successes, 1);
  });

  test('v25 DB가 v26으로 올라가면 친구 사이는 남고 내리 만난 날은 0, 옮은 버릇은 없다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/mypet.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: DateTime(2026, 10, 1),
    );
    await db.saveFriend(
      'coco',
      const Friendship(
        bond: Bond.play,
        days: 5,
        lastDay: '2026-10-03',
        name: '코코',
      ),
    );
    await db.customStatement('ALTER TABLE friends DROP COLUMN streak');
    await db.customStatement('ALTER TABLE pets DROP COLUMN habit');
    await db.customStatement('ALTER TABLE pets DROP COLUMN treats_tried');
    await db.customStatement('ALTER TABLE pets DROP COLUMN treat_shares');
    await db.customStatement('DROP TABLE kinder_photos');
    await db.customStatement(
      'ALTER TABLE pets DROP COLUMN daycare_recital_stats',
    );
    await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
    await db.customStatement('PRAGMA user_version = 25');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final coco = (await db.loadFriends())['coco']!;
    expect(coco.bond, Bond.play);
    expect(coco.days, 5);
    expect(coco.name, '코코');
    expect(coco.streak, 0);
    expect((await db.loadPet())!.habit, isNull);
  });

  test('v27 DB가 v28로 올라가면 유치원 사진 표가 생기고 일기는 그대로다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/mypet.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: DateTime(2026, 10, 1),
    );
    await db.addDiary('2026-10-03', '유치원에 갔다.', DateTime(2026, 10, 4));
    await db.customStatement('DROP TABLE kinder_photos');
    await db.customStatement('ALTER TABLE pets DROP COLUMN treat_shares');
    await db.customStatement(
      'ALTER TABLE pets DROP COLUMN daycare_recital_stats',
    );
    await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
    await db.customStatement('PRAGMA user_version = 27');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.allDiaries()).single.content, '유치원에 갔다.');
    expect(await db.allKinderPhotos(), isEmpty);
    await db.addKinderPhoto(
      KinderPhotosCompanion.insert(
        day: '2026-10-04',
        scene: 'nap',
        friends: 'kong,bami',
        stage: PetStage.puppy,
      ),
    );
    expect((await db.kinderPhotoOn('2026-10-04'))!.scene, 'nap');
  });

  test('v30 기억과 일기를 보존해 다시 열고 고정과 선택 삭제를 저장한다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_memory_migration_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/synthetic.sqlite');
    final at = DateTime(2026, 11, 24);
    var db = AppDatabase(NativeDatabase(file));
    await db.addMemory('강변 산책을 좋아한다.', at);
    await db.addMemory('치즈 냄새를 좋아한다.', at);
    await db.addDiary('2026-11-23', '같이 산책했다.', at);
    await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
    await db.customStatement('PRAGMA user_version = 30');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final old = await db.conversationMemories();
    expect(old.map((m) => m.pinned), [false, false]);
    expect(old.first.content, '치즈 냄새를 좋아한다.');
    expect(await db.setMemoryPinned(old.last.id, true), MemoryPinResult.saved);
    expect(await db.forgetMemory(old.first.id), isTrue);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final kept = (await db.conversationMemories()).single;
    expect(kept.content, '강변 산책을 좋아한다.');
    expect(kept.pinned, isTrue);
    expect((await db.allDiaries()).single.content, '같이 산책했다.');
  });

  // v11에 쓰지 않는 종 칸을 넣었고, v12에서 일기에 AI 표시 칸을 더했다.
  test('v29에서 v30으로 올려도 펫·발표회 도장·일기는 남고 과거 상태를 만들지 않는다', () async {
    final dir = Directory.systemTemp.createTempSync('mypet_v29_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/mypet.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: DateTime(2026, 10, 1),
    );
    await db.savePet(pet.copyWith(recitalDays: const Value('2026-10-09')));
    await db.addDiary('2026-10-09', '발표회에서 도장을 받았다.', DateTime(2026, 10, 10));
    await db.customStatement(
      'ALTER TABLE pets DROP COLUMN daycare_recital_stats',
    );
    await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
    await db.customStatement('PRAGMA user_version = 29');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final restored = (await db.loadPet())!;
    expect(restored.name, '콩이');
    expect(restored.recitalDays, '2026-10-09');
    expect(restored.daycareRecitalStats, isNull);
    expect((await db.allDiaries()).single.content, '발표회에서 도장을 받았다.');
  });

  for (final version in [11, 12]) {
    test('v$version DB가 v31로 올라가면 종 칸은 지우고 펫과 일기는 그대로 둔다', () async {
      final dir = Directory.systemTemp.createTempSync('mypet_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/mypet.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 9, 29),
      );
      await db.addDiary('2026-09-28', '공을 쫓았다.', DateTime(2026, 9, 29));
      await db.customStatement(
        "ALTER TABLE pets ADD COLUMN species TEXT NOT NULL DEFAULT 'dog'",
      );
      if (version < 12) {
        await db.customStatement('ALTER TABLE diaries DROP COLUMN by_ai');
      }
      await db.customStatement('ALTER TABLE pets DROP COLUMN potty_at');
      await db.customStatement('ALTER TABLE pets DROP COLUMN daycare_from');
      for (final column in [
        'treat_pouch',
        'treat_day',
        'checkup_at',
        'checkups',
        'last_weight',
        'daycare_lesson',
        'daycare_recital_stats',
        'recital_days',
        'wish',
        'wish_day',
        'wish_done',
        'paws',
        'paws_today',
        'paws_day',
        'paw_marks',
        'evening_day',
        'rug',
        'owned',
        'touch_x',
        'quirk',
        'door_news',
        'habit',
        'treats_tried',
        'treat_shares',
      ]) {
        await db.customStatement('ALTER TABLE pets DROP COLUMN $column');
      }
      await db.customStatement('ALTER TABLE tricks DROP COLUMN learned_day');
      await db.customStatement('DROP TABLE friends');
      await db.customStatement('DROP TABLE known_dogs');
      await db.customStatement('DROP TABLE kinder_photos');
      await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
      await db.customStatement('PRAGMA user_version = $version');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect((await db.loadPet())!.name, '콩이');
      final diary = (await db.allDiaries()).single;
      expect(diary.content, '공을 쫓았다.');
      expect(await db.loadKnownDogs(), isEmpty);
      expect(diary.byAi, isTrue);
      final columns = await db.customSelect('PRAGMA table_info(pets)').get();
      expect(
        columns.map((c) => c.read<String>('name')),
        isNot(contains('species')),
      );
    });
  }
}
