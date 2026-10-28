import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/hidden_treasure.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/treasure.dart';

const checkLine = '킁킁… 잘 있다';

void main() {
  group('규칙', () {
    test('확인하러 가는 건 연 때마다 정해지고(같은 분엔 같다), 열 번에 네 번쯤', () {
      final start = DateTime(2026, 10, 6);
      final due = [
        for (var i = 0; i < 1000; i++)
          hideCheckOn(start.add(Duration(minutes: i * 7))),
      ];
      expect(
        due.where((d) => d).length / due.length,
        closeTo(hideCheckChance, 0.06),
      );
      final t = DateTime(2026, 10, 6, 14, 3, 10);
      expect(hideCheckOn(t), hideCheckOn(t.add(const Duration(seconds: 40))));
    });

    test('방석으로 가서 킁킁, 하던 자리로 돌아온다. 방석 가까이 있었으면 조금 비켜 선다', () {
      final steps = hideCheckSteps(0.2);
      expect(steps.first.targetX, rugX);
      expect(steps[1].behavior, Behavior.sniff);
      expect(steps.last.targetX, 0.2);
      expect(hideCheckSteps(0.45).last.targetX, 0.3);
      expect(hideCheckSteps(0.6).last.targetX, 0.7);
      for (final s in [...steps, ...guardSteps, ...revealSteps]) {
        expect((s.thought ?? '').length, lessThanOrEqualTo(40));
      }
    });

    test('꺼내 주기는 방석을 뒤진 다음에 한 번 문다', () {
      expect(revealSteps.first.targetX, rugX);
      expect(revealSteps.where((s) => s.tag == StepTag.unearth), hasLength(1));
      final i = revealSteps.indexWhere((s) => s.tag == StepTag.unearth);
      expect(revealSteps[i - 1].behavior, Behavior.sniff);
    });

    test('숨겨 둔 건 제일 아끼는 거라 좋아하는 계열에서만', () {
      final r = Random(3);
      for (final like in Taste.values) {
        for (var i = 0; i < 50; i++) {
          final item = pickItem(
            r,
            source: FindSource.hidden,
            now: DateTime(2026, 10, 6),
            raining: false,
            like: like,
          );
          expect(item.taste, like);
        }
      }
    });
  });

  group('컨트롤러', () {
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

    Future<PetController> make({
      double affection = 50,
      String? marks,
      bool comfort = false,
    }) async {
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: now.subtract(const Duration(days: 3)),
      );
      pet = pet.copyWith(
        lastSeenAt: now,
        affection: affection,
        pawMarks: Value(marks),
        comfortDue: comfort,
      );
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

    /// 펫이 하는 대로 [seconds]초 따라간다. 걷기·달리기는 닿은 걸로 친다.
    void follow(PetController c, int seconds, [void Function()? each]) {
      for (var i = 0; i < seconds; i++) {
        now = now.add(const Duration(seconds: 1));
        if (c.step.behavior == Behavior.walk ||
            c.step.behavior == Behavior.run) {
          c.arrived();
        } else {
          c.tick(1);
        }
        each?.call();
      }
    }

    /// 확인하러 간 횟수(속마음이 새로 뜬 때를 센다).
    int countChecks(PetController c, int seconds) {
      var checks = 0;
      PetStep? last;
      follow(c, seconds, () {
        if (!identical(c.step, last) && c.step.thought == checkLine) checks++;
        last = c.step;
      });
      return checks;
    }

    test('가족이 되면 한가할 때 방석에서 숨겨 둔 걸 꺼내 물고 내민다. 받으면 선물로 도감에, 한 번뿐', () async {
      final c = await make(affection: 80);
      var unearthed = false;
      follow(c, 40, () => unearthed |= c.step.tag == StepTag.unearth);
      await pumpEventQueue(times: 20);
      expect(unearthed, isTrue);
      expect(c.hiddenGiven, isTrue);
      expect(c.presenting?.source, FindSource.hidden);
      expect(c.presenting?.gift, isTrue);
      expect((await db.loadPet())!.pawMarks, contains('hidden'));
      final got = await c.receive();
      expect(got!.source, FindSource.hidden);
      expect(got.gift, isTrue);
      expect(got.item.taste, c.pet.likeTaste);
      await pumpEventQueue(times: 20);
      expect((await events('find')).single, startsWith('방석 밑에 숨겨 뒀던'));
      // 다시는 꺼내지 않는다.
      follow(c, 120);
      await pumpEventQueue(times: 20);
      expect(c.carried.where((x) => x.source == FindSource.hidden), isEmpty);
    });

    test('열 때 챙겨 온 물건이 있으면 그걸 먼저 받은 뒤에 꺼내 준다(입에 든 게 섞이지 않게)', () async {
      final c = await make(affection: 80, comfort: true);
      expect(c.presenting?.source, FindSource.comfort);
      follow(c, 30);
      await pumpEventQueue(times: 20);
      expect(c.carried.where((x) => x.source == FindSource.hidden), isEmpty);
      await c.receive();
      follow(c, 60);
      await pumpEventQueue(times: 20);
      expect(c.presenting?.source, FindSource.hidden);
    });

    test('창틀 물건이 먼저 와 있어도 물고 온 게 먼저 입에 보이고 먼저 받는다', () async {
      await db.addCarried('moon_piece', FindSource.window, now);
      await db.addCarried('acorn', FindSource.walk, now);
      final c = await make(affection: 50);
      expect(c.presenting?.itemId, 'acorn');
      expect((await c.receive())!.item.id, 'acorn');
      expect(c.presenting?.source, FindSource.window);
    });

    test('창틀에 물건이 있어도 가족이 되면 꺼내 주고, 입에 문 보물이 먼저 나온다', () async {
      await db.addCarried('moon_piece', FindSource.window, now);
      final c = await make(affection: 80);
      follow(c, 40);
      await pumpEventQueue(times: 20);
      expect(c.presenting?.source, FindSource.hidden);
      expect((await c.receive())!.source, FindSource.hidden);
      expect(c.presenting?.source, FindSource.window);
    });

    test('가족이 되기 전엔 꺼내 주지 않는다', () async {
      final c = await make(affection: 60);
      follow(c, 120);
      await pumpEventQueue(times: 20);
      expect(c.hiddenGiven, isFalse);
      expect(c.carried, isEmpty);
    });

    test('방석을 누르면 달려와 깔고 앉는다. 또 눌러도 처음부터 다시 하지 않고, 자는 동안엔 모른다', () async {
      final c = await make(affection: 50);
      c.tapRug();
      expect(c.step.behavior, Behavior.run);
      expect(c.step.targetX, rugX);
      c.tick(1);
      final elapsed = c.stepElapsed;
      c.tapRug();
      // 같은 동작(const)이라 다시 시작해도 같은 객체다. 지난 시간으로 처음부터 다시 했는지 본다.
      expect(c.stepElapsed, elapsed);
      var guarded = false;
      follow(c, 3, () => guarded |= c.step.thought == guardLine);
      expect(guarded, isTrue);
      await pumpEventQueue(times: 20);
      expect(await events('hide'), ['주인이 방석을 건드려서 얼른 가서 깔고 앉았다']);

      c.step = const PetStep(Behavior.sleep, 60);
      c.tapRug();
      expect(c.step.behavior, Behavior.sleep);
    });

    test('꺼내 준 뒤엔 방석을 눌러도 아무 일 없다', () async {
      final c = await make(affection: 80, marks: 'hidden');
      final before = c.step;
      c.tapRug();
      expect(identical(c.step, before), isTrue);
    });

    test('확인하는 때에 열었으면 30초쯤 뒤 방석 밑을 몰래 확인하고 돌아온다(그번에 한 번)', () async {
      while (!hideCheckOn(now)) {
        now = now.add(const Duration(minutes: 1));
      }
      final c = await make(affection: 50);
      expect(countChecks(c, 150), 1);
      await pumpEventQueue(times: 20);
      expect(await events('hide'), ['방석 밑을 몰래 확인했다. 거기 있는 건 아무도 모른다']);
    });

    test('창틀에 물건이 떨어져 있어도 몰래 확인하러 간다', () async {
      while (!hideCheckOn(now)) {
        now = now.add(const Duration(minutes: 1));
      }
      await db.addCarried('moon_piece', FindSource.window, now);
      final c = await make(affection: 50);
      expect(c.presenting?.source, FindSource.window);
      expect(countChecks(c, 150), 1);
    });

    test('확인하지 않는 때에 열었으면 확인하러 가지 않는다', () async {
      while (hideCheckOn(now)) {
        now = now.add(const Duration(minutes: 1));
      }
      final c = await make(affection: 50);
      expect(countChecks(c, 150), 0);
    });

    test('꺼내 준 뒤엔(친밀도가 내려가도) 확인하러 가지 않는다', () async {
      while (!hideCheckOn(now)) {
        now = now.add(const Duration(minutes: 1));
      }
      final c = await make(affection: 50, marks: 'hidden');
      expect(countChecks(c, 150), 0);
    });
  });
}
