import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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

final appSfx = Sfx();

/// 효과음과 진동. 규칙 코드는 Cue만 알리고 무엇을 틀지는 여기서 정한다.
/// 소리는 없어도 되는 장식이라 어떤 실패도 삼킨다.
class Sfx extends ChangeNotifier {
  Sfx({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    Future<AudioPlayer?> Function(String name)? loadPlayer,
  }) : _storage = storage,
       _loadPlayer = loadPlayer ?? _loadNativePlayer;

  final FlutterSecureStorage _storage;
  final Future<AudioPlayer?> Function(String name) _loadPlayer;
  static const _soundOffKey = 'sound_off';
  static const _hapticOffKey = 'haptic_off';
  static const _audio = MethodChannel('mypet/audio');
  static const _ringerNormal = 2;
  static const _repeatGap = Duration(milliseconds: 80);
  static const _cueLifetime = Duration(milliseconds: 400);

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

  bool _soundOn = true;
  bool _hapticOn = true;
  bool _ready = false;
  int _soundRevision = 0;
  int _hapticRevision = 0;
  final _failedWrites = <String>{};
  final _settingsReady = Completer<void>();
  Future<void> _writes = Future<void>.value();
  Future<void>? _init;
  final _loading = <String, Future<_EffectVoice?>>{};
  final _voices = <String, _EffectVoice>{};
  final _clock = Stopwatch()..start();
  final _lastPlayed = <String, Duration>{};

  bool get soundOn => _soundOn;
  bool get hapticOn => _hapticOn;

  /// 설정을 읽고 소리를 미리 올려 둔다. 여러 번 불러도 한 번만 한다.
  Future<void> init() => _init ??= _start();

  Future<void> _start() async {
    final savedSound = await _storedOn(_soundOffKey);
    final savedHaptic = await _storedOn(_hapticOffKey);
    // 설정이 열리는 동안 도착한 예전 읽기로 사용자가 누른 값을 되돌리지 않는다.
    if (_soundRevision == 0) _soundOn = savedSound;
    if (_hapticRevision == 0) _hapticOn = savedHaptic;
    for (final name in sfxNames) {
      _loading[name] = _prepare(name);
    }
    _ready = true;
    _settingsReady.complete();
    notifyListeners();
    await Future.wait(_loading.values);
  }

  Future<_EffectVoice?> _prepare(String name) async {
    final player = await _loadPlayer(name);
    if (player == null) return null;
    return _voices[name] = _EffectVoice(player);
  }

  Future<bool> _storedOn(String key) async {
    try {
      return await _storage.read(key: key) != 'true';
    } on Exception {
      return true;
    }
  }

  static Future<AudioPlayer?> _loadNativePlayer(String name) async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final player = AudioPlayer()..positionUpdater = null;
      await player.setAudioContext(_context);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('sfx/$name.wav'));
      return player;
    } catch (_) {
      // 이 소리만 빠진다.
      return null;
    }
  }

  /// 스위치는 바로 바뀌고, 같은 실행의 저장은 누른 순서를 따른다.
  Future<void> setSoundOn(bool on) {
    final revision = ++_soundRevision;
    _soundOn = on;
    if (!on) silence();
    return _changed(_soundOffKey, on, () => revision == _soundRevision);
  }

  Future<void> setHapticOn(bool on) {
    final revision = ++_hapticRevision;
    _hapticOn = on;
    return _changed(_hapticOffKey, on, () => revision == _hapticRevision);
  }

  void silence() {
    for (final voice in _voices.values) {
      voice.silence();
    }
  }

  bool get needsSave => _failedWrites.isNotEmpty;

  Future<void> retrySave() async {
    final failed = Set.of(_failedWrites);
    await Future.wait([
      if (failed.contains(_soundOffKey)) setSoundOn(_soundOn),
      if (failed.contains(_hapticOffKey)) setHapticOn(_hapticOn),
    ]);
  }

  Future<void> _changed(String key, bool on, bool Function() latest) {
    _failedWrites.remove(key);
    final saved = _writes = _writes.then((_) async {
      try {
        await _storage.write(key: key, value: '${!on}');
      } on Exception {
        if (latest()) {
          _failedWrites.add(key);
          notifyListeners();
        }
      }
    });
    notifyListeners();
    return saved;
  }

  /// 첫 반김은 기기 설정이나 해당 파일이 잠시 늦어도 행동에 맞춰 한 번만 낸다.
  void play(
    Cue cue, {
    String shape = 'papillon',
    bool puppy = false,
    bool Function()? stillHere,
  }) {
    if (_init == null || (_ready && !_soundOn && !_hapticOn)) return;
    final name = sfxFor(cue, shape: shape, puppy: puppy);
    final now = _clock.elapsed;
    final last = _lastPlayed[name];
    if (last != null && now - last < _repeatGap) return;
    _lastPlayed[name] = now;
    unawaited(
      _playCue(cue, name, now, _soundRevision, _hapticRevision, stillHere),
    );
  }

  Future<void> _playCue(
    Cue cue,
    String name,
    Duration at,
    int soundRevision,
    int hapticRevision,
    bool Function()? stillHere,
  ) async {
    bool fresh() =>
        _clock.elapsed - at <= _cueLifetime && (stillHere?.call() ?? true);
    bool audible() =>
        _soundOn &&
        soundRevision == _soundRevision &&
        (stillHere?.call() ?? true);
    final initialMode = !_ready && _soundOn ? _ringerAllowsSound() : null;
    if (!_ready) {
      await _settingsReady.future.timeout(_cueLifetime, onTimeout: () {});
    }
    if (!_ready || !fresh()) return;
    if (_hapticOn && hapticRevision == _hapticRevision) {
      hapticFor(cue)?.call().ignore();
    }
    if (!audible()) return;
    if (!await (initialMode ?? _ringerAllowsSound()) ||
        !audible() ||
        !fresh()) {
      return;
    }
    final voice =
        _voices[name] ??
        await _loading[name]?.timeout(_cueLifetime, onTimeout: () => null);
    if (voice != null && fresh() && audible()) {
      voice.play(fresh: fresh, audible: audible, ringer: _ringerAllowsSound);
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

/// 저지연 플레이어는 같은 소리의 끝을 알리지 않는다. 한 파일의 정지·시작 순서를 보장한다.
class _EffectVoice {
  _EffectVoice(this.player);
  final AudioPlayer player;
  Future<void> _pending = Future<void>.value();
  bool _started = false;

  void play({
    required bool Function() fresh,
    required bool Function() audible,
    required Future<bool> Function() ringer,
  }) {
    _pending = _pending.then((_) async {
      try {
        if (!audible() || !fresh()) return;
        await player.stop();
        if (!audible() || !fresh()) return;
        if (!await ringer() || !audible() || !fresh()) return;
        _started = true;
        await player.resume();
        // 네이티브 시작 응답보다 사용자의 끄기가 먼저 끝날 수 있다.
        if (!audible()) await player.stop();
      } catch (_) {
        // 한 소리의 실패는 다음 행동 재생을 막지 않는다.
      }
    });
  }

  void silence() {
    if (!_started) return;
    _started = false;
    // 이미 나는 소리는 즉시 멈추고, 다음 시작은 이 정지와 이전 시작의 완료 뒤에 보낸다.
    final stopping = player.stop().then<void>((_) {}, onError: (Object _) {});
    _pending = Future.wait([_pending, stopping]).then((_) {});
  }
}
