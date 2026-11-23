import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/spots.dart';
import 'package:mypet/services/test_mode.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('mypet_tm_'));
  tearDown(() async {
    await pumpEventQueue(times: 100);
    dir.deleteSync(recursive: true);
  });

  test('다음 정각까지: 지났으면 다음 날', () {
    final now = DateTime(2026, 10, 5, 16, 20);
    expect(untilHour(now, 19), const Duration(hours: 2, minutes: 40));
    expect(untilHour(now, 7), const Duration(hours: 14, minutes: 40));
    expect(untilHour(DateTime(2026, 10, 5, 19), 19), const Duration(days: 1));
  });

  test('앞선 정도 글자', () {
    expect(aheadLabel(Duration.zero), '실제 시각');
    expect(aheadLabel(const Duration(minutes: 40)), '+40분');
    expect(aheadLabel(const Duration(hours: 3, minutes: 5)), '+3시간');
    expect(aheadLabel(const Duration(days: 2, hours: 3)), '+2일 3시간');
    expect(aheadLabel(const Duration(days: 7)), '+7일');
  });

  test('상태 파일이 없거나 깨져 있으면 꺼진 채로 시작하고, 저장한 건 다시 읽힌다', () async {
    final file = File('${dir.path}/test_mode.json');
    expect((await TestMode.load(file)).on, isFalse);
    file.writeAsStringSync('{깨짐');
    expect((await TestMode.load(file)).on, isFalse);

    final real = AppDatabase(NativeDatabase(File('${dir.path}/mypet.sqlite')));
    await real.createPet(
      name: '노을',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: DateTime(2026, 9, 1),
    );
    final mode = await TestMode.load(file);
    await TestMode.copyForPractice(real, '${dir.path}/mypet_test.sqlite');
    await mode.select(true);
    expect(mode.on, isTrue);
    expect(mode.dbName, TestMode.testDb);
    final again = await TestMode.load(file);
    expect(again.on, isTrue);
    expect(again.offset, Duration.zero);
    await real.close();
  });

  test('켜면 지금 펫을 통째로 복사하고, 연습 펫을 바꿔도 진짜 펫은 그대로다', () async {
    final realPath = '${dir.path}/mypet.sqlite';
    final testPath = '${dir.path}/mypet_test.sqlite';
    final real = AppDatabase(NativeDatabase(File(realPath)));
    final pet = await real.createPet(
      name: '노을',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: DateTime(2026, 9, 1),
    );
    await real.addDiary('2026-10-01', '산책했다.', DateTime(2026, 10, 2));
    final mode = TestMode(File('${dir.path}/test_mode.json'));
    // 예전에 남은 연습 파일이 있어도 새로 복사한다.
    File(testPath).writeAsStringSync('old');
    await TestMode.copyForPractice(real, testPath);
    await mode.select(true);

    final copy = AppDatabase(NativeDatabase(File(testPath)));
    final copied = (await copy.loadPet())!;
    expect(copied.name, '노을');
    expect((await copy.allDiaries()).single.content, '산책했다.');
    await copy.savePet(copied.copyWith(name: '연습'));
    expect((await real.loadPet())!.name, pet.name);
    await copy.close();
    await real.close();
  });

  test(
    '시간 보내기는 앱을 그만큼 뒤에 다시 연 것처럼 돈다: 유치원에 맡기고 저녁 7시로 보내면 버스로 집에 온다',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final mode = TestMode(File('${dir.path}/test_mode.json'), on: true);
      final base = DateTime(2026, 10, 5, 9);
      final start = DateTime.now();
      // 시계는 "실제 시각 + 보낸 시간"이다. 실제 시각 대신 고정된 시작 시각을 써서 결과를 고정한다.
      DateTime clock() =>
          base.add(mode.offset).add(DateTime.now().difference(start));
      var pet = await db.createPet(
        name: '콩이',
        stage: PetStage.adult,
        furMain: 1,
        furSecond: 2,
        marking: 3,
        now: base.subtract(const Duration(days: 5)),
      );
      pet = pet.copyWith(lastSeenAt: base);
      await db.savePet(pet);
      final c = PetController(db, pet, random: Random(1), clock: clock);
      c.wake();
      await c.collected;
      expect(c.goToKindergarten(), isTrue);
      expect(c.dropOff(), isTrue);

      await mode.jump(c, untilHour(clock(), 13));
      expect(c.inDaycare, isTrue);
      expect(c.spot, Spot.kindergarten);

      await mode.jump(c, untilHour(clock(), 19));
      expect(c.inDaycare, isFalse);
      expect(c.spot, Spot.home);

      // 카페에 있거나 산책 중이면 보내지 않는다(돌아올 시각이 없어 거기 갇힌다).
      expect(TestMode.canJump(c), isTrue);
      expect(c.goToCafe(), isTrue);
      expect(TestMode.canJump(c), isFalse);
      final atCafe = mode.offset;
      await mode.jump(c, const Duration(days: 7));
      expect(mode.offset, atCafe);
      c.comeHome();
      expect(c.startWalk(), isTrue);
      expect(TestMode.canJump(c), isFalse);
      c.endWalk();
      await c.settled;
      expect(clock().hour, 19);

      // 꺼져 있으면 보내지 않는다. 뒤로도 가지 않는다.
      final before = mode.offset;
      await mode.jump(c, const Duration(hours: -3));
      expect(mode.offset, before);
      // 하원 수업·일기 같은 뒷일이 끝난 뒤에 DB를 닫는다.
      await pumpEventQueue(times: 100);
    },
  );
}
