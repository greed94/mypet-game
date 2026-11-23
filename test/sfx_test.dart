import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/shapes.dart';
import 'package:mypet/services/sfx.dart';

class _EffectStorage extends FlutterSecureStorage {
  _EffectStorage(this.values, {this.afterRead, this.beforeWrite});

  final Map<String, String> values;
  final Future<void> Function(String key)? afterRead;
  final Future<void> Function(String key)? beforeWrite;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final snapshot = values[key];
    await afterRead?.call(key);
    return snapshot;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    await beforeWrite?.call(key);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class _CuePlayer extends Fake implements AudioPlayer {
  _CuePlayer({this.beforeStop});

  final Future<void> Function()? beforeStop;
  int starts = 0;

  @override
  Future<void> stop() async => beforeStop?.call();

  @override
  Future<void> resume() async {
    starts++;
  }
}

class _AudiblePlayer extends Fake implements AudioPlayer {
  final started = Completer<void>();
  final allowStart = Completer<void>();
  bool audible = false;
  int stops = 0;
  int resumes = 0;

  @override
  Future<void> stop() async {
    stops++;
    audible = false;
  }

  @override
  Future<void> resume() async {
    resumes++;
    if (!started.isCompleted) {
      started.complete();
      await allowStart.future;
    }
    audible = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const audio = MethodChannel('mypet/audio');

  group('고르기', () {
    test('짖는 소리는 몸집 따라 굵어진다', () {
      expect(sfxFor(Cue.bark, shape: 'papillon'), 'bark_s');
      expect(sfxFor(Cue.bark, shape: 'maltese'), 'bark_s');
      expect(sfxFor(Cue.bark, shape: 'pug'), 'bark_s');
      expect(sfxFor(Cue.bark, shape: 'shiba'), 'bark_m');
      expect(sfxFor(Cue.bark, shape: 'corgi'), 'bark_m');
      expect(sfxFor(Cue.bark, shape: 'retriever'), 'bark_l');
      expect(sfxFor(Cue.bark), 'bark_s');
      // 모르는 모양은 그림처럼 파피용 틀로 본다.
      expect(sfxFor(Cue.bark, shape: 'wolf'), 'bark_s');
    });

    test('아기는 어떤 모양이든 짖는 대신 깽', () {
      for (final s in dogShapes) {
        expect(sfxFor(Cue.bark, shape: s.id, puppy: true), 'yip');
      }
      expect(sfxFor(Cue.whine, puppy: true), 'whine');
      expect(sfxFor(Cue.sigh, shape: 'retriever', puppy: true), 'sigh');
    });

    test('진동 세기', () {
      for (final cue in [Cue.bark, Cue.chime, Cue.throwBall]) {
        expect(hapticFor(cue), HapticFeedback.mediumImpact, reason: '$cue');
      }
      for (final cue in [Cue.pickUp, Cue.drop, Cue.pop, Cue.bounce]) {
        expect(hapticFor(cue), HapticFeedback.lightImpact, reason: '$cue');
      }
      for (final cue in [Cue.yip, Cue.sniff]) {
        expect(hapticFor(cue), HapticFeedback.selectionClick, reason: '$cue');
      }
      for (final cue in [Cue.whine, Cue.sigh, Cue.crunch]) {
        expect(hapticFor(cue), isNull, reason: '$cue');
      }
    });

    test('모든 신호가 앱에 든 소리 파일로 이어지고, 안 쓰는 파일이 없다', () async {
      final used = {
        for (final cue in Cue.values)
          for (final s in dogShapes)
            for (final puppy in [false, true])
              sfxFor(cue, shape: s.id, puppy: puppy),
      };
      expect(used, sfxNames.toSet());
      final files = Directory('assets/sfx')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((f) => f.endsWith('.wav'))
          .map((f) => f.substring(0, f.length - 4))
          .toSet();
      expect(files, sfxNames.toSet());
      for (final name in sfxNames) {
        // pubspec 에 assets/sfx/ 가 빠지면 여기서 못 읽는다.
        await rootBundle.load('assets/sfx/$name.wav');
      }
    });

    test('소리 파일 규격: 16비트 모노 22050Hz, 0.05~0.6초, 최고점 -3dBFS 근처', () {
      for (final name in sfxNames) {
        final bytes = File('assets/sfx/$name.wav').readAsBytesSync();
        final b = ByteData.sublistView(bytes);
        String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
        expect(
          [tag(0), tag(8), tag(12), tag(36)],
          ['RIFF', 'WAVE', 'fmt ', 'data'],
          reason: name,
        );
        expect(b.getUint16(20, Endian.little), 1, reason: '$name PCM');
        expect(b.getUint16(22, Endian.little), 1, reason: '$name 모노');
        expect(b.getUint32(24, Endian.little), 22050, reason: name);
        expect(b.getUint16(34, Endian.little), 16, reason: name);
        final count = b.getUint32(40, Endian.little) ~/ 2;
        final seconds = count / 22050;
        expect(seconds, inInclusiveRange(0.05, 0.6), reason: '$name 길이');
        var peak = 0;
        for (var i = 0; i < count; i++) {
          peak = max(peak, b.getInt16(44 + i * 2, Endian.little).abs());
        }
        final db = 20 * log(peak / 32768) / ln10;
        if (name == 'sigh') {
          expect(db, lessThan(-5), reason: '한숨은 작게');
        } else {
          expect(db, closeTo(-3, 0.5), reason: '$name 최고점');
        }
        final first = b.getInt16(44, Endian.little).abs();
        final last = b.getInt16(44 + (count - 1) * 2, Endian.little).abs();
        expect(max(first, last), lessThan(300), reason: '$name 시작·끝은 0 근처');
      }
    });
  });

  group('설정', () {
    test('저장된 설정을 읽고, 여러 번 불러도 한 번만 한다', () async {
      FlutterSecureStorage.setMockInitialValues({'sound_off': 'true'});
      await appSfx.init();
      expect(appSfx.soundOn, isFalse);
      expect(appSfx.hapticOn, isTrue);
      expect(identical(appSfx.init(), appSfx.init()), isTrue);
    });

    test('바꾸면 바로 반영하고 저장한다', () async {
      await appSfx.setHapticOn(false);
      expect(appSfx.hapticOn, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'haptic_off'),
        'true',
      );
      await appSfx.setSoundOn(true);
      expect(appSfx.soundOn, isTrue);
      expect(
        await const FlutterSecureStorage().read(key: 'sound_off'),
        'false',
      );
    });
  });

  group('늦은 소리와 설정', () {
    for (final key in ['sound_off', 'haptic_off']) {
      test('$key 예전 읽기가 지금 사용자가 고른 값을 덮지 않는다', () async {
        final started = Completer<void>();
        final release = Completer<void>();
        final store = _EffectStorage(
          {key: 'true'},
          afterRead: (k) async {
            if (k != key) return;
            started.complete();
            await release.future;
          },
        );
        final service = Sfx(storage: store);
        final loading = service.init();
        await started.future;
        final toggle = key == 'sound_off'
            ? service.setSoundOn
            : service.setHapticOn;
        await toggle(true);
        release.complete();
        await loading;
        expect(key == 'sound_off' ? service.soundOn : service.hapticOn, isTrue);
      });

      test('$key 빠르게 껐다 켠 마지막 선택을 다시 실행해도 읽는다', () async {
        final started = Completer<void>();
        final release = Completer<void>();
        final values = <String, String>{};
        final store = _EffectStorage(
          values,
          beforeWrite: (k) async {
            if (started.isCompleted) return;
            started.complete();
            await release.future;
          },
        );
        final service = Sfx(storage: store);
        await service.init();
        final toggle = key == 'sound_off'
            ? service.setSoundOn
            : service.setHapticOn;
        final first = toggle(false);
        await started.future;
        final last = toggle(true);
        await pumpEventQueue();
        release.complete();
        await Future.wait([first, last]);
        final restarted = Sfx(storage: _EffectStorage(values));
        await restarted.init();
        expect(
          key == 'sound_off' ? restarted.soundOn : restarted.hapticOn,
          isTrue,
        );
      });
    }

    test('이미 재생을 시작한 효과음과 늦게 끝난 시작 요청도 음소거된다', () async {
      final player = _AudiblePlayer();
      final service = Sfx(
        storage: _EffectStorage({}),
        loadPlayer: (_) async => player,
      );
      await service.init();
      service.play(Cue.crunch);
      await player.started.future;
      final stops = player.stops;
      await service.setSoundOn(false);
      expect(player.stops, greaterThan(stops));
      player.allowStart.complete();
      await pumpEventQueue();
      expect(player.audible, isFalse);
      await service.setSoundOn(true);
      service.play(Cue.sigh);
      await pumpEventQueue();
      expect(player.audible, isTrue);
      await service.setSoundOn(false);
      expect(player.audible, isFalse);
    });

    test('400ms가 지나거나 방을 떠난 예전 효과음은 준비되어도 울리지 않는다', () async {
      for (final leaveRoom in [false, true]) {
        final waiting = Completer<void>();
        final release = Completer<void>();
        final player = _CuePlayer();
        final service = Sfx(
          storage: _EffectStorage({}),
          loadPlayer: (name) async {
            if (name == 'sniff') {
              waiting.complete();
              await release.future;
            }
            return player;
          },
        );
        var inRoom = true;
        final loading = service.init();
        await waiting.future;
        service.play(Cue.sniff, stillHere: () => inRoom);
        if (leaveRoom) {
          inRoom = false;
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 475));
        }
        release.complete();
        await loading;
        await pumpEventQueue();
        expect(player.starts, 0, reason: 'leaveRoom=$leaveRoom');
      }
    });

    test('초기화를 기다린 첫 신호도 저장된 무음·진동 끔을 따른다', () async {
      final entered = Completer<void>(), release = Completer<void>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final store = _EffectStorage(
        {'sound_off': 'true', 'haptic_off': 'true'},
        afterRead: (k) async {
          if (k == 'sound_off') {
            entered.complete();
            await release.future;
          }
        },
      );
      final player = _CuePlayer();
      final service = Sfx(storage: store, loadPlayer: (_) async => player);
      final loading = service.init();
      await entered.future;
      service.play(Cue.sniff);
      release.complete();
      await loading;
      await pumpEventQueue();
      expect(player.starts, 0);
      expect(calls, isEmpty);
    });

    for (final waitForSettings in [true, false]) {
      final delay = waitForSettings ? '설정 읽기' : '첫 효과음 파일 준비';
      test('$delay 중에 만난 강아지도 첫 킁킁 소리를 한 번 낸다', () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        Future<void> wait() async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        }

        final store = _EffectStorage(
          {},
          afterRead: (key) async {
            if (waitForSettings && key == 'sound_off') await wait();
          },
        );
        final player = _CuePlayer();
        final effects = Sfx(
          storage: store,
          loadPlayer: (name) async {
            if (!waitForSettings && name == 'sniff') await wait();
            return player;
          },
        );
        final loading = effects.init();
        await entered.future;
        effects.play(Cue.sniff);
        await pumpEventQueue();
        expect(player.starts, 0);
        release.complete();
        await loading;
        await pumpEventQueue();
        expect(player.starts, 1);
      });
    }

    test('설정 읽기 중 무음이었던 첫 신호도 벨소리를 켠 뒤 재생하지 않는다', () async {
      final entered = Completer<void>(), release = Completer<void>();
      var mode = 0;
      messenger.setMockMethodCallHandler(audio, (_) async => mode);
      addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
      final store = _EffectStorage(
        {},
        afterRead: (k) async {
          if (k == 'sound_off') {
            entered.complete();
            await release.future;
          }
        },
      );
      final player = _CuePlayer();
      final service = Sfx(storage: store, loadPlayer: (_) async => player);
      final loading = service.init();
      await entered.future;
      service.play(Cue.sniff);
      await pumpEventQueue();
      mode = 2;
      release.complete();
      await loading;
      await pumpEventQueue();
      expect(player.starts, 0);
    });

    test('무음 중 발생한 효과음은 파일 준비 뒤 벨소리를 켜도 돌아오지 않는다', () async {
      var mode = 0;
      messenger.setMockMethodCallHandler(audio, (_) async => mode);
      addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
      final waiting = Completer<void>(), release = Completer<void>();
      final player = _CuePlayer();
      final service = Sfx(
        storage: _EffectStorage({}),
        loadPlayer: (name) async {
          if (name == 'sniff') {
            waiting.complete();
            await release.future;
          }
          return player;
        },
      );
      final loading = service.init();
      await waiting.future;
      service.play(Cue.sniff);
      await pumpEventQueue();
      mode = 2;
      release.complete();
      await loading;
      await pumpEventQueue();
      expect(player.starts, 0);
    });

    test('플레이어 정지 대기 중 기기가 무음으로 바뀌면 첫 소리가 나지 않는다', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var mode = 2;
      messenger.setMockMethodCallHandler(audio, (_) async => mode);
      addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
      final player = _CuePlayer(
        beforeStop: () async {
          entered.complete();
          await release.future;
        },
      );
      final service = Sfx(
        storage: _EffectStorage({}),
        loadPlayer: (_) async => player,
      );
      await service.init();
      service.play(Cue.crunch);
      await entered.future;
      mode = 0;
      release.complete();
      await pumpEventQueue();
      expect(player.starts, 0);
    });

    for (final waitForMode in [true, false]) {
      final delay = waitForMode ? '벨소리 응답' : '플레이어 정지';
      test('$delay 중 끈 소리는 다시 켜도 뒤늦게 시작하지 않는다', () async {
        final started = Completer<void>();
        final release = Completer<void>();
        Future<void> wait() async {
          if (started.isCompleted) return;
          started.complete();
          await release.future;
        }

        messenger.setMockMethodCallHandler(audio, (_) async {
          if (waitForMode) await wait();
          return 2;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(audio, null));
        final player = _CuePlayer(beforeStop: waitForMode ? null : wait);
        final service = Sfx(
          storage: _EffectStorage({}),
          loadPlayer: (_) async => player,
        );
        await service.init();
        service.play(Cue.crunch);
        await started.future;
        await service.setSoundOn(false);
        await service.setSoundOn(true);
        release.complete();
        await pumpEventQueue();
        expect(player.starts, 0);
        service.play(Cue.sigh);
        await pumpEventQueue();
        expect(player.starts, 1);
      });
    }
  });

  group('재생', () {
    final calls = <String>[];
    final service = Sfx(loadPlayer: (_) async => _CuePlayer());

    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await service.init();
    });

    setUp(() async {
      calls.clear();
      await service.setSoundOn(true);
      await service.setHapticOn(true);
      messenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'HapticFeedback.vibrate') calls.add('${c.arguments}');
        return null;
      });
      messenger.setMockMethodCallHandler(audio, (c) async {
        calls.add(c.method);
        return 2;
      });
      // 앞 테스트의 같은 소리가 겹침 방지(80ms)에 걸리지 않게 한다.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(audio, null);
    });

    test('소리와 진동을 모두 끄면 아무것도 안 한다', () async {
      await service.setSoundOn(false);
      await service.setHapticOn(false);
      for (final cue in Cue.values) {
        service.play(cue);
      }
      await pumpEventQueue();
      expect(calls, isEmpty);
    });

    test('소리를 끄면 벨소리 모드도 묻지 않고 진동만', () async {
      await service.setSoundOn(false);
      service.play(Cue.bark, shape: 'retriever');
      await pumpEventQueue();
      expect(calls, ['HapticFeedbackType.mediumImpact']);
    });

    test('진동을 끄면 소리 쪽만 움직인다', () async {
      await service.setHapticOn(false);
      service.play(Cue.bark);
      await pumpEventQueue();
      expect(calls, ['ringerMode', 'ringerMode']);
    });

    test('떨지 않는 신호는 소리만', () async {
      service.play(Cue.crunch);
      await pumpEventQueue();
      expect(calls, ['ringerMode', 'ringerMode']);
    });

    test('같은 소리가 80ms 안에 겹치면 한 번만', () async {
      service.play(Cue.pop);
      service.play(Cue.pop);
      service.play(Cue.drop);
      await pumpEventQueue();
      expect(
        calls.where((c) => c == 'HapticFeedbackType.lightImpact'),
        hasLength(2),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      service.play(Cue.pop);
      await pumpEventQueue();
      expect(
        calls.where((c) => c == 'HapticFeedbackType.lightImpact'),
        hasLength(3),
      );
    });

    test('겹침 방지는 신호가 아니라 소리 파일 기준(아기 짖기 = 깽)', () async {
      service.play(Cue.bark, puppy: true);
      service.play(Cue.yip);
      await pumpEventQueue();
      expect(calls.where((c) => c == 'ringerMode'), hasLength(2));
    });

    test('플랫폼 채널이 없어도 조용히 넘어간다', () async {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(audio, null);
      for (final cue in Cue.values) {
        service.play(cue, shape: 'shiba');
      }
      await pumpEventQueue();
    });
  });
}
