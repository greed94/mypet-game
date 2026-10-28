import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../pet/cues.dart';

/// assets/sfx/ 파일 이름. tools/make_sfx.py 가 만든다.
const sfxNames = [
  'bark_s',
  'bark_m',
  'bark_l',
  'yip',
  'whine',
  'sigh',
  'sniff',
  'throw',
  'bounce',
  'pickup',
  'drop',
  'chime',
  'crunch',
  'pop',
];

/// 짖는 소리는 몸집 따라 굵어지고, 아기는 짖는 대신 "깽" 한다.
String sfxFor(Cue cue, {String shape = 'papillon', bool puppy = false}) =>
    switch (cue) {
      Cue.bark when puppy => 'yip',
      Cue.bark => switch (shape) {
        'retriever' => 'bark_l',
        'shiba' || 'corgi' => 'bark_m',
        _ => 'bark_s',
      },
      Cue.yip => 'yip',
      Cue.whine => 'whine',
      Cue.sigh => 'sigh',
      Cue.sniff => 'sniff',
      Cue.throwBall => 'throw',
      Cue.bounce => 'bounce',
      Cue.pickUp => 'pickup',
      Cue.drop => 'drop',
      Cue.chime => 'chime',
      Cue.crunch => 'crunch',
      Cue.pop => 'pop',
    };

/// 낑낑·한숨·씹기는 떨지 않는다. 잔잔한 순간까지 떨면 진동이 성가셔진다.
Future<void> Function()? hapticFor(Cue cue) => switch (cue) {
  Cue.bark || Cue.chime || Cue.throwBall => HapticFeedback.mediumImpact,
  Cue.pickUp || Cue.drop || Cue.pop || Cue.bounce => HapticFeedback.lightImpact,
  Cue.yip || Cue.sniff => HapticFeedback.selectionClick,
  Cue.whine || Cue.sigh || Cue.crunch => null,
};

/// 효과음과 진동. 규칙 코드는 Cue만 알리고 무엇을 틀지는 여기서 정한다.
/// 소리는 없어도 되는 장식이라 어떤 실패도 삼킨다.
class Sfx {
  Sfx._();

  static const _storage = FlutterSecureStorage();
  static const _soundOffKey = 'sound_off';
  static const _hapticOffKey = 'haptic_off';
  static const _audio = MethodChannel('mypet/audio');
  static const _ringerNormal = 2;
  static const _repeatGap = Duration(milliseconds: 80);

  // 다른 앱 음악을 끊지 않게 오디오 포커스를 요청하지 않고 섞는다. 음량은 미디어 음량을 따른다.
  // iOS ambient는 무음 스위치를 스스로 따르고 다른 소리와 섞인다.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static bool _soundOn = true;
  static bool _hapticOn = true;
  static bool _ready = false;
  static Future<void>? _init;
  static final _players = <String, AudioPlayer>{};
  static final _clock = Stopwatch()..start();
  static final _lastPlayed = <String, Duration>{};

  static bool get soundOn => _soundOn;
  static bool get hapticOn => _hapticOn;

  /// 설정을 읽고 소리를 미리 올려 둔다. 여러 번 불러도 한 번만 한다.
  static Future<void> init() => _init ??= _start();

  static Future<void> _start() async {
    try {
      _soundOn = await _storage.read(key: _soundOffKey) != 'true';
      _hapticOn = await _storage.read(key: _hapticOffKey) != 'true';
    } on Exception {
      // 저장소가 깨져도 기본값(둘 다 켜짐)으로 간다.
    }
    _ready = true;
    // PC에서 도는 테스트에는 오디오 플러그인이 없다.
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await Future.wait(sfxNames.map(_load));
  }

  static Future<void> _load(String name) async {
    try {
      final player = AudioPlayer()..positionUpdater = null;
      await player.setAudioContext(_context);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('sfx/$name.wav'));
      _players[name] = player;
    } catch (_) {
      // 이 소리만 빠진다.
    }
  }

  /// 바로 반영하고 저장은 뒤따른다.
  static Future<void> setSoundOn(bool on) async {
    _soundOn = on;
    await _save(_soundOffKey, !on);
  }

  static Future<void> setHapticOn(bool on) async {
    _hapticOn = on;
    await _save(_hapticOffKey, !on);
  }

  static Future<void> _save(String key, bool off) async {
    try {
      await _storage.write(key: key, value: '$off');
    } on Exception {
      // 저장이 안 되면 이번 실행 동안만 적용된다.
    }
  }

  /// 소리와 진동을 함께 낸다. 폰이 무음·진동 모드면 진동만.
  static void play(Cue cue, {String shape = 'papillon', bool puppy = false}) {
    if (!_ready || (!_soundOn && !_hapticOn)) return;
    final name = sfxFor(cue, shape: shape, puppy: puppy);
    final now = _clock.elapsed;
    final last = _lastPlayed[name];
    // 여러 규칙이 한 프레임에 같은 신호를 내도 소리가 겹쳐 커지지 않게 한다.
    if (last != null && now - last < _repeatGap) return;
    _lastPlayed[name] = now;
    final buzz = hapticFor(cue);
    if (_hapticOn && buzz != null) buzz().ignore();
    if (_soundOn) unawaited(_playSound(name));
  }

  static Future<void> _playSound(String name) async {
    if (!await _ringerAllowsSound()) return;
    final player = _players[name];
    if (player == null) return;
    try {
      // 저지연 모드는 끝났다는 신호가 없어서, 멈춰 두지 않으면 다시 틀어지지 않는다.
      await player.stop();
      await player.resume();
    } catch (_) {
      // 소리가 안 나도 펫은 움직인다.
    }
  }

  static Future<bool> _ringerAllowsSound() async {
    try {
      final mode = await _audio.invokeMethod<int>('ringerMode');
      return mode == null || mode == _ringerNormal;
    } on Exception {
      // 물어볼 수 없으면(iOS, 테스트) 소리를 낸다.
      return true;
    }
  }
}
