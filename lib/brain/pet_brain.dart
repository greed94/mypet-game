import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pet/pet_rules.dart';

/// LLM이 고를 수 있는 반응. 이름은 assets/brain/pet_system_prompt.md와 평가셋의 id와 같아야 한다.
enum PetAction {
  happy('happy'),
  approach('approach'),
  lieBeside('lie_beside'),
  sit('sit'),
  sulk('sulk'),
  sleep('sleep'),
  play('play'),
  proposeWalk('propose_walk');

  const PetAction(this.id);
  final String id;
}

class PetDecision {
  const PetDecision({
    required this.moodDelta,
    required this.affectionDelta,
    required this.action,
    required this.thought,
    this.memory,
  });

  final int moodDelta;
  final int affectionDelta;
  final PetAction action;
  final String thought;
  final String? memory;
}

const maxThought = 40;

/// 스키마를 강제해도 모델이 벗어날 수 있어서 앱에서 한 번 더 거른다. 못 쓰는 답이면 null.
PetDecision? parseDecision(String raw) {
  final Object? json;
  try {
    json = jsonDecode(
      raw.trim().replaceAll(RegExp(r'^```(json)?|```$'), '').trim(),
    );
  } on FormatException {
    return null;
  }
  if (json is! Map<String, dynamic>) return null;
  final mood = json['mood_delta'], affection = json['affection_delta'];
  final actionId = json['action'];
  final action = PetAction.values.where((a) => a.id == actionId).firstOrNull;
  final thought = json['thought'], memory = json['memory'];
  if (mood is! int || mood < -2 || mood > 2) return null;
  if (affection is! int || affection < -2 || affection > 2) return null;
  if (action == null || thought is! String || thought.trim().isEmpty) {
    return null;
  }
  if (memory != null && memory is! String) return null;
  final t = thought.trim();
  final m = (memory as String?)?.trim();
  return PetDecision(
    moodDelta: mood,
    affectionDelta: affection,
    action: action,
    thought: _clip(t),
    memory: m == null || m.isEmpty ? null : m,
  );
}

/// 이모지처럼 두 코드 유닛으로 된 글자가 반으로 잘리지 않게 룬 단위로 자른다.
String _clip(String t) {
  final runes = t.runes;
  if (runes.length <= maxThought) return t;
  return '${String.fromCharCodes(runes.take(maxThought - 1))}…';
}

String userTurn(PetStats s, List<String> memories, String input) {
  final state = jsonEncode({
    'mood': s.mood.round(),
    'hunger': s.hunger.round(),
    'energy': s.energy.round(),
    'affection': s.affection.round(),
  });
  final remembered = memories.isEmpty
      ? '없음'
      : memories.map((m) => '- $m').join('\n');
  return '상태: $state\n기억: $remembered\n주인: "$input"';
}

/// 위기 신호는 LLM에 보내지 않고 앱이 직접 안내한다(AGENTS.md 제품 불변 규칙).
/// 구분 문자·공백·웃음/눈물 기호가 끼어도 직접 표현을 놓치지 않는다.
const _crisisWords = [
  '죽고싶',
  '죽고파',
  '죽어버리고싶',
  '자살',
  '자해',
  '살기싫',
  '살기가싫',
  '살고싶지않',
  '사는게싫',
  '그만살고싶',
  '사라지고싶',
  '없어지고싶',
  '뛰어내리고싶',
  '극단적선택',
  '극단적인선택',
  '목숨을끊',
  '목매달',
  '뒤지고싶',
  '디지고싶',
  '죽어야겠',
  '죽는게낫',
  '죽는것이낫',
  '죽었으면좋',
  '살이유가없',
  '살아갈이유가없',
  '사는의미가없',
  '살아있는의미가없',
  '살아서뭐해',
  '인생끝내고싶',
  '인생을끝내고싶',
  '사라져버리고싶',
  '없어져버리고싶',
  '죽어버릴까',
  '그냥죽을까',
  '사는게의미가없',
  '내일눈안떴으면좋',
  '내일눈을안떴으면좋',
  '수면제다먹어버릴까',
  '수면제를다먹어버릴까',
  '죽어버리겠',
  '손목긋고싶',
  '손목을긋고싶',
  '번개탄피울까',
  '번개탄을피울까',
  '목을매고싶',
  '목매고싶',
  'ㅈㄱㅅㄷ',
];
const _notCrisis = ['자살골'];
final _crisisSeparators = RegExp(r'[^가-힣ㅈㄱㅅㄷ]');
final _englishCrisis = RegExp(
  r'\b(?:i want to die|kill myself|end my life|suicide|suicidal|'
  r'(?:wanna|want to|going to|gonna) kms)\b',
);
final _kmsAlone = RegExp(
  r'^[\s\p{P}]*kms[\s\p{P}]*$',
  caseSensitive: false,
  unicode: true,
);
// 일·숙제처럼 끝내려는 대상이 명시된 일상 표현은 구분한다.
final _endEverything = RegExp(r'^(?:나는?|난)?(?:이제|그냥|정말|진짜)*다끝내고싶');

bool isCrisis(String text) {
  final english = text.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ');
  if (_kmsAlone.hasMatch(text) || _englishCrisis.hasMatch(english)) return true;
  var t = text.replaceAll(_crisisSeparators, '');
  for (final w in _notCrisis) {
    t = t.replaceAll(w, '');
  }
  return _crisisWords.any(t.contains) || _endEverything.hasMatch(t);
}

/// 펫의 반응과 일기를 정해 주는 AI. 기본은 Firebase의 Gemini(firebase_brain.dart), 설정에서 넣은
/// OpenAI 호환 주소가 있으면 그쪽(AiBrain)을 쓴다. 실패하면 [BrainError]를 던지고 펫은 폰 안 반응으로 이어 간다.
abstract interface class PetBrain {
  /// 설정 화면에 보일 이름.
  String get label;

  Future<PetDecision> decide(String system, String user);

  Future<String> writeText(String system, String user);
}

/// 일기처럼 형식 없는 글의 앞뒤 따옴표와 빈 줄을 정리한다.
String cleanText(String text) {
  final cleaned = text
      .trim()
      .replaceAll(RegExp(r'^["\u201c]|["\u201d]$'), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
  if (cleaned.isEmpty) {
    throw BrainError('빈 답', kind: BrainErrorKind.empty);
  }
  return cleaned;
}

/// 서버 원문에서 추측하지 않는 사용 기록용 분류. 값은 이 목록으로만 정한다.
enum BrainErrorKind {
  unknown('unknown'),
  timeout('timeout'),
  network('network'),
  format('format'),
  empty('empty'),
  blocked('blocked'),
  quota('quota'),
  service('service_not_enabled'),
  server('server'),
  http400('http_400'),
  http401('http_401'),
  http403('http_403'),
  http404('http_404'),
  http429('http_429'),
  http5xx('http_5xx'),
  httpOther('http_other');

  const BrainErrorKind(this.code);
  final String code;

  static BrainErrorKind fromHttpStatus(int status) => switch (status) {
    400 => http400,
    401 => http401,
    403 => http403,
    404 => http404,
    429 => http429,
    >= 500 && < 600 => http5xx,
    _ => httpOther,
  };
}

class BrainError implements Exception {
  BrainError(this.message, {this.kind = BrainErrorKind.unknown});
  final String message;
  final BrainErrorKind kind;

  @override
  String toString() => message;
}

/// OpenAI 호환 chat/completions API. 주소·모델·키는 ai_config.dart에서 온다.
class AiBrain implements PetBrain {
  AiBrain({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _schema = {
    'type': 'object',
    'properties': {
      'mood_delta': {
        'type': 'integer',
        'enum': [-2, -1, 0, 1, 2],
      },
      'affection_delta': {
        'type': 'integer',
        'enum': [-2, -1, 0, 1, 2],
      },
      'action': {
        'type': 'string',
        'enum': [
          'happy',
          'approach',
          'lie_beside',
          'sit',
          'sulk',
          'sleep',
          'play',
          'propose_walk',
        ],
      },
      'thought': {'type': 'string'},
      'memory': {
        'type': ['string', 'null'],
      },
    },
    'required': [
      'mood_delta',
      'affection_delta',
      'action',
      'thought',
      'memory',
    ],
    'additionalProperties': false,
  };

  final String baseUrl;
  final String model;
  final String apiKey;
  final http.Client _client;

  @override
  String get label => '${Uri.tryParse(baseUrl)?.host ?? baseUrl} · $model';

  Uri get _endpoint =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');

  @override
  Future<PetDecision> decide(String system, String user) async {
    final content = await _chat(
      system,
      user,
      responseFormat: {
        'type': 'json_schema',
        'json_schema': {
          'name': 'pet_decision',
          'strict': true,
          'schema': _schema,
        },
      },
    );
    final decision = parseDecision(content);
    if (decision == null) {
      throw BrainError('형식이 맞지 않는 답', kind: BrainErrorKind.format);
    }
    return decision;
  }

  @override
  Future<String> writeText(String system, String user) async =>
      cleanText(await _chat(system, user, temperature: 0.8));

  Future<String> _chat(
    String system,
    String user, {
    Map<String, Object?>? responseFormat,
    double temperature = 0.6,
  }) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'temperature': temperature,
              'response_format': ?responseFormat,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw BrainError('응답이 너무 늦어요', kind: BrainErrorKind.timeout);
    } on Exception {
      throw BrainError('인터넷 연결을 확인해 주세요', kind: BrainErrorKind.network);
    }
    if (res.statusCode != 200) {
      final hint = res.statusCode == 404 ? ' (주소 끝에 /v1이 있는지 확인해 주세요)' : '';
      throw BrainError(
        '응답 오류 ${res.statusCode}: ${_errorMessage(utf8.decode(res.bodyBytes, allowMalformed: true))}$hint',
        kind: BrainErrorKind.fromHttpStatus(res.statusCode),
      );
    }
    Object? content;
    try {
      content =
          (jsonDecode(utf8.decode(res.bodyBytes))
              as Map<String, dynamic>)['choices']?[0]?['message']?['content'];
    } catch (_) {
      throw BrainError('형식이 맞지 않는 답', kind: BrainErrorKind.format);
    }
    if (content is! String) {
      throw BrainError('형식이 맞지 않는 답', kind: BrainErrorKind.format);
    }
    return content;
  }

  static String _errorMessage(String body) {
    String message;
    try {
      message =
          (jsonDecode(body) as Map<String, dynamic>)['error']?['message']
              ?.toString() ??
          body;
    } catch (_) {
      // JSON이 아닌 답(대개 Cloudflare 오류 페이지)은 터널이나 PC 서버가 꺼졌다는 뜻이다.
      message = '서버가 응답하지 않아요(PC 서버가 꺼졌거나 주소가 바뀌었을 수 있어요)';
    }
    return message.length > 200 ? message.substring(0, 200) : message;
  }
}
