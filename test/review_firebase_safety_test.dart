import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/brain/firebase_brain.dart';
import 'package:mypet/brain/pet_brain.dart';

GenerateContentResponse reply(
  String text, {
  FinishReason reason = FinishReason.stop,
}) => GenerateContentResponse([
  Candidate(Content.text(text), [], null, reason, null),
], null);

void main() {
  test('대화와 일기는 네 위험 범주를 중간 이상 차단 기준으로 요청한다', () async {
    var calls = 0;
    final brain = FirebaseBrain(
      generate: (model, system, user, config, settings) async {
        calls++;
        expect(settings.map((s) => s.category).toSet(), {
          HarmCategory.harassment,
          HarmCategory.hateSpeech,
          HarmCategory.sexuallyExplicit,
          HarmCategory.dangerousContent,
        });
        expect(
          settings.every((s) => s.threshold == HarmBlockThreshold.medium),
          isTrue,
        );
        if (config.responseMimeType == 'application/json') {
          return reply(
            '{"mood_delta":0,"affection_delta":0,"action":"sit",'
            '"thought":"곁에 있을게.","memory":null}',
          );
        }
        return reply('합성 검사 일기.');
      },
    );
    expect((await brain.decide('synthetic', 'hello')).thought, '곁에 있을게.');
    expect(await brain.writeText('synthetic', 'diary'), '합성 검사 일기.');
    expect(calls, 2);
  });

  for (final reason in [
    FinishReason.safety,
    FinishReason.blocklist,
    FinishReason.prohibitedContent,
    FinishReason.spii,
    FinishReason.recitation,
  ]) {
    test('차단된 ${reason.name} 답변은 본문이 있어도 쓰지 않는다', () async {
      final brain = FirebaseBrain(
        generate: (model, system, user, config, settings) async =>
            reply('synthetic blocked text', reason: reason),
      );
      for (final request in [
        brain.decide('synthetic', 'input'),
        brain.writeText('synthetic', 'input'),
      ]) {
        await expectLater(
          request,
          throwsA(
            isA<BrainError>().having(
              (e) => e.message,
              'safe notice',
              '안전 기준에 따라 답변을 표시하지 않았어요',
            ),
          ),
        );
      }
    });
  }

  test('입력 단계 차단도 서버 원문 없이 실패로 돌려준다', () async {
    final brain = FirebaseBrain(
      generate: (model, system, user, config, settings) async =>
          GenerateContentResponse(
            [],
            PromptFeedback(BlockReason.safety, 'synthetic private input', []),
          ),
    );
    await expectLater(
      brain.decide('synthetic', 'input'),
      throwsA(
        isA<BrainError>().having(
          (e) => e.message,
          'safe notice',
          '안전 기준에 따라 답변을 표시하지 않았어요',
        ),
      ),
    );
  });
}
