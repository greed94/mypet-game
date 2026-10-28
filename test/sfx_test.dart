import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/cues.dart';
import 'package:mypet/pet/shapes.dart';
import 'package:mypet/services/sfx.dart';

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
      await Sfx.init();
      expect(Sfx.soundOn, isFalse);
      expect(Sfx.hapticOn, isTrue);
      expect(identical(Sfx.init(), Sfx.init()), isTrue);
    });

    test('바꾸면 바로 반영하고 저장한다', () async {
      await Sfx.setHapticOn(false);
      expect(Sfx.hapticOn, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'haptic_off'),
        'true',
      );
      await Sfx.setSoundOn(true);
      expect(Sfx.soundOn, isTrue);
      expect(
        await const FlutterSecureStorage().read(key: 'sound_off'),
        'false',
      );
    });
  });

  group('재생', () {
    final calls = <String>[];

    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await Sfx.init();
    });

    setUp(() async {
      calls.clear();
      await Sfx.setSoundOn(true);
      await Sfx.setHapticOn(true);
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
      await Sfx.setSoundOn(false);
      await Sfx.setHapticOn(false);
      for (final cue in Cue.values) {
        Sfx.play(cue);
      }
      await pumpEventQueue();
      expect(calls, isEmpty);
    });

    test('소리를 끄면 벨소리 모드도 묻지 않고 진동만', () async {
      await Sfx.setSoundOn(false);
      Sfx.play(Cue.bark, shape: 'retriever');
      await pumpEventQueue();
      expect(calls, ['HapticFeedbackType.mediumImpact']);
    });

    test('진동을 끄면 소리 쪽만 움직인다', () async {
      await Sfx.setHapticOn(false);
      Sfx.play(Cue.bark);
      await pumpEventQueue();
      expect(calls, ['ringerMode']);
    });

    test('떨지 않는 신호는 소리만', () async {
      Sfx.play(Cue.crunch);
      await pumpEventQueue();
      expect(calls, ['ringerMode']);
    });

    test('같은 소리가 80ms 안에 겹치면 한 번만', () async {
      Sfx.play(Cue.pop);
      Sfx.play(Cue.pop);
      Sfx.play(Cue.drop);
      await pumpEventQueue();
      expect(
        calls.where((c) => c == 'HapticFeedbackType.lightImpact'),
        hasLength(2),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      Sfx.play(Cue.pop);
      await pumpEventQueue();
      expect(
        calls.where((c) => c == 'HapticFeedbackType.lightImpact'),
        hasLength(3),
      );
    });

    test('겹침 방지는 신호가 아니라 소리 파일 기준(아기 짖기 = 깽)', () async {
      Sfx.play(Cue.bark, puppy: true);
      Sfx.play(Cue.yip);
      await pumpEventQueue();
      expect(calls.where((c) => c == 'ringerMode'), hasLength(1));
    });

    test('플랫폼 채널이 없어도 조용히 넘어간다', () async {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(audio, null);
      for (final cue in Cue.values) {
        Sfx.play(cue, shape: 'shiba');
      }
      await pumpEventQueue();
    });
  });
}
