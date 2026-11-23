import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_rules.dart';

class _FailingUpgrade extends AppDatabase {
  _FailingUpgrade(File file) : super(NativeDatabase(file));
  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) {
    if (statement.startsWith('ALTER TABLE') &&
        statement.contains('daycare_recital_stats')) {
      throw StateError('synthetic second migration failure');
    }
    return super.customStatement(statement, args);
  }
}

class _Version28 extends AppDatabase {
  _Version28(File file) : super(NativeDatabase(file));
  @override
  int get schemaVersion => 28;
}

class _FailAfterUpgrade extends AppDatabase {
  _FailAfterUpgrade(File file) : super(NativeDatabase(file));
  @override
  MigrationStrategy get migration {
    final original = super.migration;
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        await original.onUpgrade(m, from, to);
        throw StateError('synthetic failure after migration commit');
      },
    );
  }
}

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mypet_migration_atomic_');
    file = File('${dir.path}/synthetic.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    try {
      await db.createPet(
        name: '검사펫',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: DateTime(2026, 10, 21),
      );
      await db.addDiary('2026-10-20', '합성 검사 일기.', DateTime(2026, 10, 21));
      await db.customStatement('ALTER TABLE pets DROP COLUMN treat_shares');
      await db.customStatement(
        'ALTER TABLE pets DROP COLUMN daycare_recital_stats',
      );
      await db.customStatement(
        'ALTER TABLE memories DROP COLUMN heard_event_id',
      );
      await db.customStatement('ALTER TABLE memories DROP COLUMN pinned');
      await db.customStatement('PRAGMA user_version = 28');
    } finally {
      await db.close();
    }
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('두 번째 업그레이드 쓰기가 실패하면 첫 칸과 버전도 되돌아가 재시도된다', () async {
    final failing = _FailingUpgrade(file);
    try {
      await expectLater(failing.loadPet(), throwsStateError);
    } finally {
      await failing.close();
    }
    final old = _Version28(file);
    try {
      final columns = await old.customSelect('PRAGMA table_info(pets)').get();
      expect(
        columns.map((r) => r.read<String>('name')),
        isNot(contains('treat_shares')),
      );
      expect(
        (await old.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        28,
      );
      expect(
        (await old.customSelect('SELECT name FROM pets').getSingle())
            .read<String>('name'),
        '검사펫',
      );
      expect((await old.allDiaries()).single.content, '합성 검사 일기.');
    } finally {
      await old.close();
    }
    final retry = AppDatabase(NativeDatabase(file));
    try {
      expect((await retry.loadPet())!.name, '검사펫');
      expect((await retry.allDiaries()).single.content, '합성 검사 일기.');
      expect(
        (await retry.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        retry.schemaVersion,
      );
    } finally {
      await retry.close();
    }
  });

  test('업그레이드 커밋 직후 열기가 실패해도 버전과 칸이 함께 남아 다시 열린다', () async {
    final failing = _FailAfterUpgrade(file);
    try {
      await expectLater(failing.loadPet(), throwsStateError);
    } finally {
      await failing.close();
    }
    final retry = AppDatabase(NativeDatabase(file));
    try {
      expect((await retry.loadPet())!.name, '검사펫');
      expect((await retry.allDiaries()).single.content, '합성 검사 일기.');
      expect(
        (await retry.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        retry.schemaVersion,
      );
    } finally {
      await retry.close();
    }
  });
}
