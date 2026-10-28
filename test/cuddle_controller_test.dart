import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/cuddle.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 10, 6, 14);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 6, 14);
  });
  tearDown(() async {
    await pumpEventQueue(times: 100);
    await db.close();
  });

  Future<PetController> make({double affection = 50}) async {
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now.subtract(const Duration(days: 3)),
    );
    pet = pet.copyWith(lastSeenAt: now, affection: affection);
    await db.savePet(pet);
    final c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await c.collected;
    c.stats = c.stats.copyWith(energy: 90, hunger: 20, mood: 60);
    c.step = const PetStep(Behavior.idle, 3);
    return c;
  }

  Future<List<String>> events(String kind) async => [
    for (final e in await db.eventsOn(now))
      if (e.kind == kind) e.detail,
  ];

  /// 손 베개를 마칠 때까지(손을 뗀 뒤 계획이 끝나면 손을 거둔다).
  void finishHand(PetController c) {
    for (var i = 0; i < 40 && c.handX != null; i++) {
      c.tick(1);
    }
  }

  /// 손에 닿을 때(StepTag.hand)까지. 걷기는 닿으면 끝난다.
  void reachHand(PetController c) {
    for (var i = 0; i < 30 && c.step.tag != StepTag.hand; i++) {
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
  }

  test('친해진 펫은 내민 손에 와서 비비고, 기분·친밀도가 오르고 일기에 남는다', () async {
    final c = await make();
    expect(c.canOfferHand, isTrue);
    expect(c.triedHand, isFalse);
    final mood = c.stats.mood, affection = c.stats.affection;
    c.offerHand(0.3);
    expect(c.handX, closeTo(0.3, 1e-9));
    // 아직 펫이 손에 닿기 전이라 '써 봤다'로 치지 않는다.
    expect(c.triedHand, isFalse);
    expect(c.step.targetX, closeTo(0.3, 1e-9));
    reachHand(c);
    expect(c.step.tag, StepTag.hand);
    expect(c.step.thought, '이 손 좋아');
    expect(c.stats.mood, greaterThan(mood));
    expect(c.stats.affection, affection + 1);
    await pumpEventQueue(times: 20);
    expect(await events('cuddle'), ['주인 손에 얼굴을 비볐다']);
    expect(c.triedHand, isTrue);
    expect((await db.loadPet())!.pawMarks, contains('hand'));
    // 손을 떼도 펫이 손 베개를 마칠 때까지 손은 남고, 마치면 거둔다.
    c.releaseHand();
    expect(c.handX, isNotNull);
    finishHand(c);
    expect(c.handX, isNull);
  });

  test('닿기 전에 손을 떼도(손가락이 밀려 취소돼도) 펫은 와서 마치고, 그다음 손을 거둔다', () async {
    final c = await make();
    c.offerHand(0.7);
    c.releaseHand();
    expect(c.handX, closeTo(0.7, 1e-9));
    reachHand(c);
    expect(c.step.tag, StepTag.hand);
    expect(c.step.thought, '이 손 좋아');
    finishHand(c);
    expect(c.handX, isNull);
    await pumpEventQueue(times: 20);
    expect(await events('cuddle'), ['주인 손에 얼굴을 비볐다']);
  });

  test('손은 한 번에 하나(두 손가락이면 처음 것만)', () async {
    final c = await make();
    c.offerHand(0.3);
    c.offerHand(0.8);
    expect(c.handX, closeTo(0.3, 1e-9));
    expect(c.step.targetX, closeTo(0.3, 1e-9));
  });

  test('가족이 된 펫은 손을 베고 눕고, 밤이면 그대로 잠든다', () async {
    final day = await make(affection: 80);
    day.offerHand(0.5);
    reachHand(day);
    expect(day.step.behavior, Behavior.lieBeside);
    expect(day.step.thought, '여기가 내 자리야');

    await pumpEventQueue(times: 50);
    await db.close();
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 6, 23, 50);
    final night = await make(affection: 80);
    night.offerHand(0.5);
    reachHand(night);
    expect(night.step.behavior, Behavior.sleep);
    expect(night.step.thought, '여기서 잘래…');
    await pumpEventQueue(times: 20);
    expect(await events('cuddle'), ['주인 손을 베고 잠들었다']);
  });

  test('낯가리는 펫은 멀찍이서 냄새만 맡는다', () async {
    final c = await make(affection: 10);
    c.offerHand(0.5);
    expect((c.step.targetX! - 0.5).abs(), closeTo(0.16, 1e-9));
    reachHand(c);
    expect(c.step.behavior, Behavior.sniff);
  });

  test('깊이 자고 있으면 손이 놓여도 오지 않는다', () async {
    now = DateTime(2026, 10, 6, 23, 50);
    final c = await make();
    c.step = const PetStep(Behavior.sleep, 60);
    c.offerHand(0.5);
    expect(c.handX, isNotNull);
    expect(c.step.behavior, Behavior.sleep);
    // 오지 않으니 떼면 바로 거두고, '써 봤다'로 치지 않는다(안내가 계속 뜬다).
    c.releaseHand();
    expect(c.handX, isNull);
    expect(c.triedHand, isFalse);
  });

  test('손 베개 친밀도는 10분에 한 번(되풀이로 쌓지 않는다)', () async {
    final c = await make();
    final affection = c.stats.affection;
    for (var i = 0; i < 3; i++) {
      c.offerHand(0.4);
      reachHand(c);
      c.releaseHand();
      finishHand(c);
      now = now.add(const Duration(minutes: 2));
    }
    expect(c.stats.affection, affection + 1);
    now = now.add(handBondEvery);
    c.offerHand(0.4);
    reachHand(c);
    expect(c.stats.affection, affection + 2);
  });

  test('공을 꺼냈거나 물건을 내밀고 있으면 손 베개는 안 된다', () async {
    final c = await make();
    c.takeOutBall();
    expect(c.canOfferHand, isFalse);
    c.offerHand(0.5);
    expect(c.handX, isNull);
  });

  test('가족이 된 펫은 한동안 아무것도 안 하면 와서 조르고, 곧 쓰다듬으면 앵긴다(한 번 연 동안 한 번)', () async {
    final c = await make(affection: 80);
    final thoughts = <String>[];
    for (var i = 0; i < 80 && c.step.tag != StepTag.beg; i++) {
      now = now.add(const Duration(seconds: 1));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      if (c.step.thought case final t?) thoughts.add(t);
    }
    expect(c.step.tag, StepTag.beg);
    now = now.add(const Duration(seconds: 3));
    c.interact(Interaction.pet);
    final after = <String>[];
    var jumped = false;
    for (var i = 0; i < 8; i++) {
      c.tick(1);
      if (c.step.behavior == Behavior.jump) jumped = true;
      if (c.step.thought case final t?) after.add(t);
    }
    expect(jumped, isTrue);
    expect(after, contains('헤헤'));
    await pumpEventQueue(times: 20);
    expect(await events('cuddle'), ['조르러 갔더니 주인이 쓰다듬어 줬다']);

    // 같은 번에 다시 조르지 않는다.
    final begs = <StepTag>[];
    for (var i = 0; i < 200; i++) {
      now = now.add(const Duration(seconds: 1));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      begs.add(c.step.tag);
    }
    expect(begs, isNot(contains(StepTag.beg)));
  });

  test('카페에 다녀온 직후나 다른 탭을 보는 동안, 졸릴 땐 조르지 않는다', () async {
    final c = await make(affection: 80);
    expect(c.goToCafe(), isTrue);
    now = now.add(const Duration(minutes: 2));
    for (var i = 0; i < 120; i++) {
      c.tick(1);
      if (c.step.behavior == Behavior.walk) c.arrived();
    }
    c.comeHome();
    final tags = <StepTag>[];
    for (var i = 0; i < 30; i++) {
      now = now.add(const Duration(seconds: 1));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      tags.add(c.step.tag);
    }
    expect(tags, isNot(contains(StepTag.beg)));

    // 일기 탭을 보는 동안엔 한참 지나도 안 조른다.
    c.roomHidden = true;
    for (var i = 0; i < 120; i++) {
      now = now.add(const Duration(seconds: 1));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
      tags.add(c.step.tag);
    }
    expect(tags, isNot(contains(StepTag.beg)));
  });

  test('다른 탭을 보는 동안엔 쉬도 마렵지 않다(못 본 채 실수하지 않게)', () async {
    final c = await make();
    c.roomHidden = true;
    now = now.add(const Duration(hours: 5));
    // 신호는 8초 뒤 그 자리에서 끝나니, 한 번이라도 켜졌는지 본다.
    var urged = false;
    for (var i = 0; i < 120; i++) {
      now = now.add(const Duration(seconds: 1));
      c.tick(1);
      if (c.step.behavior == Behavior.walk) c.arrived();
      urged |= c.pottyUrge;
    }
    expect(urged, isFalse);
    // 방 탭으로 돌아오면 마렵다.
    c.roomHidden = false;
    for (var i = 0; i < 120 && !urged; i++) {
      now = now.add(const Duration(seconds: 1));
      c.tick(1);
      if (c.step.behavior == Behavior.walk) c.arrived();
      urged |= c.pottyUrge;
    }
    expect(urged, isTrue);
  });

  test('조르기를 안 받아 줘도 아무 일 없다. 친밀도·일기 그대로', () async {
    final c = await make(affection: 80);
    final affection = c.stats.affection;
    for (var i = 0; i < 120; i++) {
      now = now.add(const Duration(seconds: 1));
      if (c.step.behavior == Behavior.walk || c.step.behavior == Behavior.run) {
        c.arrived();
      } else {
        c.tick(1);
      }
    }
    expect(c.stats.affection, affection);
    await pumpEventQueue(times: 20);
    expect(await events('cuddle'), isEmpty);
  });

  test('친한 사이(가족 전)나 계속 만지작거리면 조르지 않는다', () async {
    final friend = await make(affection: 50);
    final tags = <StepTag>[];
    for (var i = 0; i < 120; i++) {
      now = now.add(const Duration(seconds: 1));
      friend.tick(1);
      if (friend.step.behavior == Behavior.walk) friend.arrived();
      tags.add(friend.step.tag);
    }
    expect(tags, isNot(contains(StepTag.beg)));
  });
}
