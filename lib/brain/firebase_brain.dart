import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import 'pet_brain.dart';

typedef FirebaseGenerate =
    Future<GenerateContentResponse> Function(
      String model,
      String system,
      String user,
      GenerationConfig config,
      List<SafetySetting> safetySettings,
    );

/// 기본 AI. Firebase를 거쳐 구글 Gemini를 부른다. 키가 앱 밖(구글 쪽)에 있어 따로 서버가 필요 없다.
/// 무료 한도는 Firebase 프로젝트 전체가 나눠 쓰고, 하루 한도는 미국 서부 자정(한국 오후 4~5시)에 초기화된다.
class FirebaseBrain implements PetBrain {
  FirebaseBrain({this.model = defaultModel, FirebaseGenerate? generate})
    : _request = generate ?? _requestFirebase;

  final FirebaseGenerate _request;

  static Future<GenerateContentResponse> _requestFirebase(
    String model,
    String system,
    String user,
    GenerationConfig config,
    List<SafetySetting> safetySettings,
  ) => FirebaseAI.googleAI()
      .generativeModel(
        model: model,
        generationConfig: config,
        safetySettings: safetySettings,
        systemInstruction: Content.system(system),
      )
      .generateContent([Content.text(user)]);

  /// 가볍고 빠르며 무료 등급에서 쓸 수 있는 모델(Firebase AI Logic 문서, 2026-09).
  static const defaultModel = 'gemini-3.5-flash-lite';

  final String model;

  static final _schema = Schema.object(
    properties: {
      'mood_delta': Schema.integer(minimum: -2, maximum: 2),
      'affection_delta': Schema.integer(minimum: -2, maximum: 2),
      'action': Schema.enumString(
        enumValues: [for (final a in PetAction.values) a.id],
      ),
      'thought': Schema.string(),
      'memory': Schema.string(nullable: true),
    },
    propertyOrdering: [
      'mood_delta',
      'affection_delta',
      'action',
      'thought',
      'memory',
    ],
  );

  @override
  String get label => 'Google Gemini ($model)';

  @override
  Future<PetDecision> decide(String system, String user) async {
    final text = await _generate(
      system,
      user,
      GenerationConfig(
        temperature: 0.6,
        responseMimeType: 'application/json',
        responseSchema: _schema,
      ),
    );
    final decision = parseDecision(text);
    if (decision == null) {
      throw BrainError('형식이 맞지 않는 답', kind: BrainErrorKind.format);
    }
    return decision;
  }

  @override
  Future<String> writeText(String system, String user) async => cleanText(
    await _generate(system, user, GenerationConfig(temperature: 0.8)),
  );

  Future<String> _generate(
    String system,
    String user,
    GenerationConfig config,
  ) async {
    try {
      // 모델별 기본값에 기대지 않고 대화·일기에 같은 차단 기준을 보낸다.
      final settings = [
        for (final category in [
          HarmCategory.harassment,
          HarmCategory.hateSpeech,
          HarmCategory.sexuallyExplicit,
          HarmCategory.dangerousContent,
        ])
          SafetySetting(category, HarmBlockThreshold.medium, null),
      ];
      final res = await _request(
        model,
        system,
        user,
        config,
        settings,
      ).timeout(const Duration(seconds: 20));
      final finish = res.candidates.firstOrNull?.finishReason;
      if (res.promptFeedback?.blockReason != null ||
          const {
            FinishReason.safety,
            FinishReason.blocklist,
            FinishReason.prohibitedContent,
            FinishReason.spii,
            FinishReason.recitation,
          }.contains(finish)) {
        throw BrainError(
          '안전 기준에 따라 답변을 표시하지 않았어요',
          kind: BrainErrorKind.blocked,
        );
      }
      final text = res.text;
      if (text == null || text.trim().isEmpty) {
        throw BrainError('빈 답', kind: BrainErrorKind.empty);
      }
      return text;
    } on TimeoutException {
      throw BrainError('응답이 너무 늦어요', kind: BrainErrorKind.timeout);
    } on QuotaExceeded {
      throw BrainError(
        'AI 사용량 제한에 닿았어요. 잠시 뒤 다시 시도해 주세요.',
        kind: BrainErrorKind.quota,
      );
    } on ServiceApiNotEnabled {
      throw BrainError(
        'Firebase 콘솔에서 AI Logic을 켜야 해요',
        kind: BrainErrorKind.service,
      );
    } on InvalidApiKey catch (e) {
      throw BrainError('AI 오류: ${e.message}', kind: BrainErrorKind.http401);
    } on ServerException catch (e) {
      throw BrainError('AI 오류: ${e.message}', kind: BrainErrorKind.server);
    } on FirebaseAIException catch (e) {
      throw BrainError('AI 오류: ${e.message}');
    } on BrainError {
      rethrow;
    } catch (_) {
      // Firebase가 안 떴거나 인터넷이 끊긴 경우. 펫은 폰 안 반응으로 이어 간다.
      throw BrainError('인터넷 연결을 확인해 주세요', kind: BrainErrorKind.network);
    }
  }
}
