import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:mypet/brain/firebase_brain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mypet/brain/pet_brain.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/services/telemetry.dart';

const privateError = 'SYNTHETIC_PRIVATE_SERVER_ERROR';

Future<({AppDatabase db, PetController c})> fixture(
  PetBrain brain, {
  Duration away = Duration.zero,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime(2026, 10, 22, 12);
  final pet = await db.createPet(
    name: '검사펫',
    stage: PetStage.adult,
    furMain: 1,
    furSecond: 2,
    marking: 3,
    now: now.subtract(away),
  );
  return (
    db: db,
    c: PetController(
      db,
      pet,
      brain: brain,
      random: Random(1),
      clock: () => now,
    ),
  );
}

AiBrain rejected([int status = 401]) => AiBrain(
  baseUrl: 'https://synthetic.invalid/v1',
  model: 'synthetic',
  apiKey: 'synthetic',
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({
        'error': {'message': privateError},
      }),
      status,
    ),
  ),
);

Future<void> closeFixture(({AppDatabase db, PetController c}) f) async {
  await f.c.settled;
  f.c.dispose();
  await f.db.close();
}

void main() {
  test('반김 오류도 원문 대신 분류만 기록한다', () async {
    final f = await fixture(rejected(), away: const Duration(hours: 6));
    final events = <(String, Map<String, Object>)>[];
    try {
      await Telemetry.captureEvents(
        (name, params) => events.add((name, params)),
        () async {
          f.c.wake();
          await f.c.settled;
        },
      );
      expect(events.where((e) => e.$1 == 'greet_error').single.$2, {
        'error': 'http_401',
      });
      expect(
        events.any((e) => e.$2.toString().contains(privateError)),
        isFalse,
      );
    } finally {
      await closeFixture(f);
    }
  });

  test('일기 오류는 분류만 기록하고 폰 일기를 저장한다', () async {
    final f = await fixture(rejected(503));
    final now = DateTime(2026, 10, 22, 12);
    final events = <(String, Map<String, Object>)>[];
    try {
      await f.db.addEvent('feed', '주인이 밥을 줬다', now);
      final diary = await Telemetry.captureEvents(
        (name, params) => events.add((name, params)),
        () => f.c.writeDiary(now),
      );
      expect(diary, isNotNull);
      expect(diary!.byAi, isFalse);
      expect((await f.db.allDiaries()).single.byAi, isFalse);
      expect(events.where((e) => e.$1 == 'diary_error').single.$2, {
        'error': 'http_5xx',
      });
      expect(
        events.any((e) => e.$2.toString().contains(privateError)),
        isFalse,
      );
    } finally {
      await closeFixture(f);
    }
  });

  test('HTTP 오류는 응답 문장과 무관하게 닫힌 분류로 변환한다', () async {
    for (final (status, code) in [
      (400, 'http_400'),
      (401, 'http_401'),
      (403, 'http_403'),
      (404, 'http_404'),
      (429, 'http_429'),
      (500, 'http_5xx'),
      (599, 'http_5xx'),
      (418, 'http_other'),
      (302, 'http_other'),
    ]) {
      await expectLater(
        rejected(status).decide('s', 'u'),
        throwsA(isA<BrainError>().having((e) => e.kind.code, 'code', code)),
      );
    }
  });

  test('시간 초과·네트워크 오류도 원문 없이 분류한다', () async {
    for (final (error, kind) in [
      (TimeoutException(privateError), BrainErrorKind.timeout),
      (http.ClientException(privateError), BrainErrorKind.network),
    ]) {
      final brain = AiBrain(
        baseUrl: 'https://synthetic.invalid/v1',
        model: 'synthetic',
        apiKey: 'synthetic',
        client: MockClient((_) async => throw error),
      );
      await expectLater(
        brain.decide('s', 'u'),
        throwsA(isA<BrainError>().having((e) => e.kind, 'kind', kind)),
      );
    }
  });

  test('잘못된 응답 형식과 빈 일기는 서버 문장으로 분류하지 않는다', () async {
    for (final (body, kind) in [
      ('<html>synthetic</html>', BrainErrorKind.format),
      ('{"choices":[]}', BrainErrorKind.format),
    ]) {
      final brain = AiBrain(
        baseUrl: 'https://synthetic.invalid/v1',
        model: 'synthetic',
        apiKey: 'synthetic',
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        brain.decide('s', 'u'),
        throwsA(isA<BrainError>().having((e) => e.kind, 'kind', kind)),
      );
    }
    expect(
      () => cleanText('   '),
      throwsA(
        isA<BrainError>().having((e) => e.kind, 'kind', BrainErrorKind.empty),
      ),
    );
  });

  test('Firebase 오류의 고정 분류와 알 수 없는 오류 기본값을 유지한다', () async {
    for (final (error, kind) in [
      (QuotaExceeded(privateError), BrainErrorKind.quota),
      (ServiceApiNotEnabled('synthetic'), BrainErrorKind.service),
      (InvalidApiKey(privateError), BrainErrorKind.http401),
      (ServerException(privateError), BrainErrorKind.server),
      (FirebaseAIException(privateError), BrainErrorKind.unknown),
      (TimeoutException(privateError), BrainErrorKind.timeout),
    ]) {
      final brain = FirebaseBrain(
        generate: (model, system, user, config, settings) async => throw error,
      );
      await expectLater(
        brain.writeText('s', 'u'),
        throwsA(isA<BrainError>().having((e) => e.kind, 'kind', kind)),
      );
    }
    expect(BrainError(privateError).kind, BrainErrorKind.unknown);
    expect(BrainError(privateError).message, privateError);
  });

  test('Firebase 안전 차단도 폰 반응으로 이어지고 분류만 기록한다', () async {
    final brain = FirebaseBrain(
      generate: (model, system, user, config, settings) async =>
          GenerateContentResponse(
            [],
            PromptFeedback(BlockReason.safety, privateError, []),
          ),
    );
    final f = await fixture(brain);
    final events = <(String, Map<String, Object>)>[];
    try {
      expect(
        await Telemetry.captureEvents(
          (name, params) => events.add((name, params)),
          () => f.c.talk('안녕'),
        ),
        TalkOutcome.failed,
      );
      expect(f.c.bubble, isNotNull);
      expect(
        events.where((e) => e.$1 == 'talk_outcome').last.$2['error'],
        'blocked',
      );
      expect(
        events.any((e) => e.$2.toString().contains(privateError)),
        isFalse,
      );
    } finally {
      await closeFixture(f);
    }
  });

  test('합성 기록 수집은 비동기 작업끼리 섞이지 않고 실제 전송 없이 끝난다', () async {
    final first = <String>[];
    final second = <String>[];
    final release = Completer<void>();
    await Future.wait([
      Telemetry.captureEvents((name, params) => first.add(name), () async {
        await release.future;
        Telemetry.track('first');
      }),
      Telemetry.captureEvents((name, params) => second.add(name), () async {
        Telemetry.track('second');
        release.complete();
      }),
    ]);
    Telemetry.track('outside');
    expect(first, ['first']);
    expect(second, ['second']);
    expect(Telemetry.active, isFalse);
  });

  test('AI 서버 오류 원문은 대화 사용 기록에 들어가지 않는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 10, 22, 12);
    final pet = await db.createPet(
      name: '검사펫',
      stage: PetStage.adult,
      furMain: 1,
      furSecond: 2,
      marking: 3,
      now: now,
    );
    final brain = AiBrain(
      baseUrl: 'https://synthetic.invalid/v1',
      model: 'synthetic',
      apiKey: 'synthetic',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': privateError},
          }),
          401,
        ),
      ),
    );
    final c = PetController(
      db,
      pet,
      brain: brain,
      random: Random(1),
      clock: () => now,
    );
    final events = <(String, Map<String, Object>)>[];
    try {
      final outcome = await Telemetry.captureEvents(
        (name, params) => events.add((name, params)),
        () => c.talk('안녕'),
      );
      expect(outcome, TalkOutcome.failed);
      expect(c.lastError, contains(privateError));
      final failure = events
          .where((e) => e.$1 == 'talk_outcome' && e.$2['outcome'] == 'failed')
          .single
          .$2;
      expect(failure['error'], 'http_401');
      expect(
        jsonEncode(events.map((e) => e.$2).toList()),
        isNot(contains(privateError)),
      );
    } finally {
      await c.settled;
      c.dispose();
      await db.close();
    }
  });
}
