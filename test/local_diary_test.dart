import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/local_diary.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

DayEvent ev(int h, String kind, String detail) =>
    (at: DateTime(2026, 10, 5, h), kind: kind, detail: detail);

void main() {
  test('카페 방문은 일기 재료가 되고 산책보다 뒤, 밥보다 앞에 선다', () {
    final text = localDiary([
      ev(8, 'feed', '주인이 밥을 줬다'),
      ev(9, 'pet', '주인이 쓰다듬어 줬다'),
      ev(10, 'talk', '주인이 말을 걸어 줬다'),
      ev(11, 'place', '주인이 도토리를 선반에 놓아 줬다'),
      ev(15, 'cafe', '카페에 가서 다른 강아지 2마리를 구경했다'),
    ], Random(1))!;
    expect(text, contains('카페에 가서 다른 강아지 2마리를 구경했다.'));
    expect(text, contains('선반에 놓아 줬다. 카페에'));
    expect(text, isNot(contains('쓰다듬어')));
  });

  test('그날 큰 일 넷까지 시간 순서로 잇고, 때가 바뀔 때만 아침·저녁을 붙인다', () {
    final text = localDiary([
      ev(8, 'feed', '주인이 밥을 줬다'),
      ev(9, 'pet', '주인이 쓰다듬어 줬다'),
      ev(19, 'greet', '주인이 9시간 만에 돌아와서 꼬리를 흔들며 반겼다'),
      ev(20, 'play', '주인이 던진 공을 물어 왔다'),
      ev(21, 'trick', "주인이 가르쳐 준 '앉아'를 처음으로 해냈다"),
      ev(22, 'weather', '오늘 날씨는 맑음'),
    ], Random(1))!;
    expect(text, contains('저녁에 주인이 9시간 만에'));
    expect(text, contains("밤에 주인이 가르쳐 준 '앉아'를 처음으로 해냈다."));
    expect(text, isNot(contains('날씨')));
    final order = [
      text.indexOf('밥을'),
      text.indexOf('9시간'),
      text.indexOf('공을'),
      text.indexOf('앉아'),
    ];
    expect(order, [...order]..sort());
    expect(text, contains('내일도 같이 놀고 싶다.'));
  });

  test('주인이 한 말은 일기에 옮기지 않는다', () {
    final text = localDiary([
      ev(23, 'talk', '주인이 "회사 그만두고 싶어"라고 했다. 옆에 엎드려 있었다'),
    ], Random(1))!;
    expect(text, isNot(contains('회사')));
    expect(text, contains('주인이 말을 걸어 줬다'));
  });

  test('쓸 만한 일이 없으면 일기를 쓰지 않는다', () {
    expect(localDiary(const [], Random(1)), isNull);
    expect(localDiary([ev(10, 'unknown', '뭔가')], Random(1)), isNull);
  });

  test('AI가 없어도 다음 날 처음 열면 어제 일기를 폰이 쓰고, AI 표시는 없다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var now = DateTime(2026, 10, 5, 20);
    var pet = await db.createPet(
      name: '콩이',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    var c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    c.interact(Interaction.feed);
    await pumpEventQueue();
    c.sleepApp();
    await pumpEventQueue();
    now = DateTime(2026, 10, 6, 9);
    pet = (await db.loadPet())!;
    c = PetController(db, pet, random: Random(1), clock: () => now);
    c.wake();
    await pumpEventQueue(times: 50);
    final diaries = await db.allDiaries();
    expect(diaries.single.day, '2026-10-05');
    expect(diaries.single.byAi, isFalse);
    expect(diaries.single.content, contains('밥을 줬다'));
    await pumpEventQueue(times: 50);
  });
}
