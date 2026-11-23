import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/art/photo_art.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

class _DelayedAppearanceDb extends AppDatabase {
  _DelayedAppearanceDb() : super(NativeDatabase.memory());
  final started = Completer<void>();
  final release = Completer<void>();
  final writes = <String?>[];

  @override
  Future<bool> saveAppearance(
    int id,
    int main,
    int second,
    int marking,
    String? portrait,
  ) async {
    writes.add(portrait);
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.saveAppearance(id, main, second, marking, portrait);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('겹친 두 외모 저장과 늦은 돌봄이 각각 최근 초상화와 돌봄 수치를 지킨다', () async {
    final db = _DelayedAppearanceDb();
    final original = await db.createPet(
      name: '가상 펫',
      stage: PetStage.puppy,
      furMain: 3,
      furSecond: 4,
      marking: 5,
      portraitPath: 'original.png',
      now: DateTime(2026, 11, 24),
    );
    final c = PetController(db, original);
    try {
      final first = c.changeColors(
        const PetColors(main: 10, second: 11, marking: 12),
        portraitPath: 'a.png',
      );
      await db.started.future;
      final second = c.changeColors(
        const PetColors(main: 20, second: 21, marking: 22),
        portraitPath: 'b.png',
      );
      expect(c.pet.portraitPath, 'original.png');
      expect(db.writes, ['a.png']);
      await db.savePetState(original.copyWith(energy: 37));
      db.release.complete();
      expect((await first)!.previousPortrait, 'original.png');
      expect((await second)!.previousPortrait, 'a.png');
      await db.savePetState(original.copyWith(energy: 22));
      final saved = (await db.loadPet())!;
      expect(db.writes, ['a.png', 'b.png']);
      expect(saved.portraitPath, 'b.png');
      expect(saved.furMain, 20);
      expect(saved.energy, 22);
      expect(c.pet.portraitPath, saved.portraitPath);
    } finally {
      if (!db.release.isCompleted) db.release.complete();
      await c.settled;
      c.dispose();
      await db.close();
    }
  });
}
