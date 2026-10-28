import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/pet/walk_log.dart';

/// 산책 블랙박스(아이디어 C4): 산책이 끝나면 길 낙서와 오래 킁킁댄 자리가 남는다.
void main() {
  final start = DateTime(2026, 10, 5, 18, 20);

  test('킁킁댄 만큼 자리가 생기고(셋까지) 길 순서대로, 이름은 겹치지 않는다', () {
    expect(walkSpots(start, 0), isEmpty);
    expect(walkSpots(start, 1), hasLength(1));
    final spots = walkSpots(start, 7);
    expect(spots, hasLength(3));
    expect(spots.map((s) => s.name).toSet(), hasLength(3));
    for (var i = 0; i + 1 < spots.length; i++) {
      expect(spots[i].at, lessThan(spots[i + 1].at));
    }
    expect(walkSpots(start, 7), spots);
  });

  test('비 오는 날엔 물웅덩이, 눈 오는 날엔 눈 쌓인 화단이 먼저', () {
    expect(walkSpots(start, 2, rain: true).first.name, '물웅덩이');
    expect(walkSpots(start, 2, snow: true).first.name, '눈 쌓인 화단');
  });

  test('길 낙서는 왼쪽 집에서 오른쪽 집까지, 산책마다 다르다', () {
    final path = walkPath(start);
    expect(path.first, (0.0, 0.5));
    expect(path.last, (1.0, 0.5));
    expect(walkPath(start.add(const Duration(minutes: 1))), isNot(path));
  });

  test('일기 줄은 첫 킁킁 자리 하나', () {
    expect(walkSpotLine(const []), isNull);
    expect(walkSpotLine(const [(name: '풀숲', at: 0.3)]), '산책길 풀숲에서 한참 킁킁댔다');
  });

  test('산책 중 킁킁댄 걸 세어 끝날 때 자리와 일기 줄로 남긴다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });
    var now = DateTime(2026, 10, 5, 18);
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(lastSeenAt: now, pawMarks: const Value('hidden'));
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(3), clock: () => now);
    c.wake();
    await c.collected;
    c.stats = c.stats.copyWith(energy: 90);
    expect(c.startWalk(), isTrue);
    for (var i = 0; i < 120 && c.walkSniffs < 2; i++) {
      if (c.step.behavior == Behavior.walk) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
    expect(c.walkSniffs, greaterThanOrEqualTo(2));
    now = now.add(const Duration(minutes: 15));
    final r = c.endWalk();
    expect(r.spots, hasLength(min(3, c.walkSniffs)));
    expect(r.startedAt, DateTime(2026, 10, 5, 18));
    await pumpEventQueue(times: 20);
    final lines = [
      for (final e in await db.eventsOn(now))
        if (e.kind == 'walk_spot') e.detail,
    ];
    expect(lines, [walkSpotLine(r.spots)]);
    // 다음 산책은 처음부터 센다.
    c.stats = c.stats.copyWith(energy: 90);
    c.startWalk();
    expect(c.walkSniffs, 0);
  });

  test('명령을 못 알아들은 킁킁은 산책 지도 자리로 세지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await pumpEventQueue(times: 100);
      await db.close();
    });
    final now = DateTime(2026, 10, 5, 18);
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(lastSeenAt: now, pawMarks: const Value('hidden'));
    await db.savePet(pet);
    final c = PetController(db, pet, random: _Miss(), clock: () => now);
    c.wake();
    await c.collected;
    c.stats = c.stats.copyWith(energy: 90);
    c.startWalk();
    c.command(Trick.down);
    expect(c.step.thought, '킁킁… 응? 뭐라고?');
    expect(c.walkSniffs, 0);
  });
}

/// 늘 못 해내고, 못 알아들은 반응은 첫 번째(킁킁).
class _Miss implements Random {
  @override
  double nextDouble() => 0.99;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
