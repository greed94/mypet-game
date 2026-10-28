import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';

class _Brain implements PetBrain {
  int decisions = 0;
  int diaries = 0;
  BrainErrorKind? firstError;
  Completer<void>? diaryGate;
  final diaryStarted = Completer<void>();

  @override
  String get label => '합성 검사';

  @override
  Future<PetDecision> decide(String system, String user) async {
    decisions++;
    if (decisions == 1 && firstError != null) {
      throw BrainError('합성 오류', kind: firstError!);
    }
    return const PetDecision(
      moodDelta: 0,
      affectionDelta: 0,
      action: PetAction.sit,
      thought: '곁에 있을게.',
    );
  }

  @override
  Future<String> writeText(String system, String user) async {
    diaries++;
    if (!diaryStarted.isCompleted) diaryStarted.complete();
    await diaryGate?.future;
    return '주인이 밥을 줬다.';
  }
}

class _Fixture {
  _Fixture(this.db, this.c, this.brain, this.now);
  final AppDatabase db;
  final PetController c;
  final _Brain brain;
  DateTime now;
}

Future<_Fixture> _fixture({int used = 0, BrainErrorKind? error}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime(2026, 10, 28, 12);
  var pet = await db.createPet(
    name: '검사펫',
    stage: PetStage.adult,
    furMain: 1,
    furSecond: 2,
    marking: 3,
    now: now,
  );
  pet = pet.copyWith(countDay: Value(dayKey(petDate(now))), talksToday: used);
  await db.savePet(pet);
  final brain = _Brain()..firstError = error;
  late _Fixture f;
  final c = PetController(
    db,
    pet,
    brain: brain,
    random: Random(1),
    clock: () => f.now,
  );
  f = _Fixture(db, c, brain, now);
  addTearDown(() async {
    if (brain.diaryGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    await c.settled;
    c.dispose();
    await db.close();
  });
  return f;
}

void main() {
  test('오늘 미리 보기도 대화 하루 몫을 사용하고 재시작에 저장한다', () async {
    final f = await _fixture();
    await f.db.addEvent('feed', '주인이 밥을 줬다', f.now);
    for (var i = 0; i <= PetController.dailyTalkLimit; i++) {
      final result = await f.c.writeDiary(f.now, save: false);
      expect(result, isNotNull);
      expect(result!.byAi, i < PetController.dailyTalkLimit);
    }
    expect(f.brain.diaries, PetController.dailyTalkLimit);
    expect((await f.db.loadPet())!.talksToday, PetController.dailyTalkLimit);
    expect(await f.db.allDiaries(), isEmpty);
  });

  test('미리 보기 두 개가 마지막 AI 몫을 동시에 쓰지 않는다', () async {
    final f = await _fixture(used: PetController.dailyTalkLimit - 1);
    f.brain.diaryGate = Completer<void>();
    await f.db.addEvent('feed', '주인이 밥을 줬다', f.now);
    final first = f.c.writeDiary(f.now, save: false);
    await f.brain.diaryStarted.future;
    final second = await f.c.writeDiary(f.now, save: false);
    f.brain.diaryGate!.complete();
    final initial = await first;
    expect(initial!.byAi, isTrue);
    expect(second!.byAi, isFalse);
    expect(f.brain.diaries, 1);
    expect(f.c.pet.talksToday, PetController.dailyTalkLimit);
  });

  test('자동 저장 일기는 대화 몫을 다 써도 별도로 작성한다', () async {
    final f = await _fixture(used: PetController.dailyTalkLimit);
    await f.db.addEvent('feed', '주인이 밥을 줬다', f.now);
    final diary = await f.c.writeDiary(f.now);
    expect(diary!.byAi, isTrue);
    expect(f.brain.diaries, 1);
    expect((await f.db.allDiaries()).single.byAi, isTrue);
    expect(f.c.pet.talksToday, PetController.dailyTalkLimit);
  });

  test('일이 없는 미리 보기는 AI 몫을 쓰지 않는다', () async {
    final f = await _fixture();
    expect(await f.c.writeDiary(f.now, save: false), isNull);
    expect(f.c.pet.talksToday, 0);
    expect(f.brain.diaries, 0);
  });

  test('안전 차단 뒤 정상 대화는 바로 AI에 전달한다', () async {
    final f = await _fixture(error: BrainErrorKind.blocked);
    expect(await f.c.talk('안녕'), TalkOutcome.failed);
    expect(await f.c.talk('다녀왔어'), TalkOutcome.ai);
    expect(f.brain.decisions, 2);
  });

  test('형식 오류와 빈 답 뒤에도 다음 대화를 10분 막지 않는다', () async {
    for (final kind in [BrainErrorKind.format, BrainErrorKind.empty]) {
      final f = await _fixture(error: kind);
      expect(await f.c.talk('안녕'), TalkOutcome.failed);
      expect(await f.c.talk('다녀왔어'), TalkOutcome.ai);
    }
  });

  test('일시적 연결 실패는 30초 뒤 다음 요청에서 회복한다', () async {
    for (final kind in [
      BrainErrorKind.timeout,
      BrainErrorKind.network,
      BrainErrorKind.server,
      BrainErrorKind.http5xx,
    ]) {
      final f = await _fixture(error: kind);
      expect(await f.c.talk('안녕'), TalkOutcome.failed);
      f.now = f.now.add(const Duration(seconds: 29));
      expect(await f.c.talk('다녀왔어'), TalkOutcome.failed);
      expect(f.brain.decisions, 1);
      f.now = f.now.add(const Duration(seconds: 1));
      expect(await f.c.talk('다녀왔어'), TalkOutcome.ai);
      expect(f.brain.decisions, 2);
    }
  });

  test('HTTP 429는 1분 쉬고 한도 종류가 불명확하면 10분을 유지한다', () async {
    final limited = await _fixture(error: BrainErrorKind.http429);
    await limited.c.talk('안녕');
    limited.now = limited.now.add(const Duration(seconds: 59));
    expect(await limited.c.talk('다녀왔어'), TalkOutcome.failed);
    limited.now = limited.now.add(const Duration(seconds: 1));
    expect(await limited.c.talk('다녀왔어'), TalkOutcome.ai);
    final quota = await _fixture(error: BrainErrorKind.quota);
    await quota.c.talk('안녕');
    quota.now = quota.now.add(const Duration(minutes: 1));
    expect(await quota.c.talk('다녀왔어'), TalkOutcome.failed);
    quota.now = quota.now.add(const Duration(minutes: 9));
    expect(await quota.c.talk('다녀왔어'), TalkOutcome.ai);
  });
}
