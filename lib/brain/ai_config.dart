import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pet_brain.dart';

/// 기본 AI(Firebase의 Gemini) 대신 OpenAI 호환 API(Groq, OpenAI 등)를 쓰고 싶을 때 주소·모델·키를 넣는다.
class AiConfig {
  const AiConfig(this.url, this.model, this.key);

  final String url;
  final String model;
  final String key;

  bool get complete => url.isNotEmpty && model.isNotEmpty && key.isNotEmpty;

  AiBrain toBrain() => AiBrain(baseUrl: url, model: model, apiKey: key);

  static const groqUrl = 'https://api.groq.com/openai/v1';
  static const groqModel = 'openai/gpt-oss-20b';
}

const _storage = FlutterSecureStorage();

// 설정을 다시 열어도 여러 키의 저장·삭제를 중간에 섞지 않는다.
Future<void> _configQueue = Future<void>.value();

Future<T> _inConfigOrder<T>(Future<T> Function() action) {
  final next = _configQueue.then((_) => action());
  _configQueue = next.then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {},
  );
  return next;
}

const _url = 'ai_url',
    _model = 'ai_model',
    _key = 'ai_key',
    _legacyGroqKey = 'groq_api_key';

/// 저장된 설정 → 예전 Groq 키 순서. 없으면 null이고 기본 AI(Gemini)를 쓴다. 저장소가 깨져도 앱은 떠야 한다.
Future<AiConfig?> loadAiConfig() => _inConfigOrder(_loadAiConfig);

Future<AiConfig?> _loadAiConfig() async {
  try {
    final url = await _storage.read(key: _url);
    final model = await _storage.read(key: _model);
    final key = await _storage.read(key: _key);
    if (url != null && model != null && key != null) {
      return AiConfig(url, model, key);
    }
    final legacy = await _storage.read(key: _legacyGroqKey);
    if (legacy != null) {
      return AiConfig(AiConfig.groqUrl, AiConfig.groqModel, legacy);
    }
  } on PlatformException {
    // 기본 AI로 계속한다.
  }
  return null;
}

Future<void> saveAiConfig(AiConfig c, {void Function()? onApply}) =>
    _inConfigOrder(() async {
      // 실행 중 연결 변경도 저장·삭제와 같은 순서로 반영한다.
      onApply?.call();
      await _storage.write(key: _url, value: c.url);
      await _storage.write(key: _model, value: c.model);
      await _storage.write(key: _key, value: c.key);
      await _storage.delete(key: _legacyGroqKey);
    });

Future<void> clearAiConfig({void Function()? onCleared}) =>
    _inConfigOrder(() async {
      for (final k in [_url, _model, _key, _legacyGroqKey]) {
        await _storage.delete(key: k);
      }
      onCleared?.call();
    });
