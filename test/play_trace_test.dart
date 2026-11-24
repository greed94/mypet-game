import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/pet/tricks.dart';
import 'package:mypet/services/telemetry.dart';

enum _Ball { ready, none }

enum _Outcome { success }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mypet-play-log-');
  });
  tearDown(() => directory.delete(recursive: true));

  test('연타 입력을 구분하고, 설정된 돌봄·탭 이름과 화면 결과만 로컬 파일에 남긴다', () async {
    final lines = <String>[];
    await Telemetry.capturePlayTrace(lines.add, () async {
      final first = Telemetry.playTrace(
        PlayAction.trick,
        PlayPhase.pointer,
        trick: Trick.fetch,
      );
      final second = Telemetry.playTrace(PlayAction.close, PlayPhase.pointer);
      expect(first, isNot(second));
      Telemetry.playTrace(
        PlayAction.trick,
        PlayPhase.result,
        input: first,
        ball: _Ball.ready,
        attempts: 5,
        successes: 3,
        stars: 1,
        outcome: _Outcome.success,
      );
      Telemetry.playTrace(
        PlayAction.close,
        PlayPhase.frame,
        input: second,
        atCafe: false,
        ball: _Ball.none,
        menuOpen: false,
      );
      Telemetry.track('tap', {'what': 'feed', 'other': 'private-text'});
      Telemetry.track('tab', {'to': 'diary'});
      Telemetry.track('tab', {'to': 'private-text'});
      Telemetry.track('talk', {'body': 'private-text'});
      Telemetry.recordFlutterError(
        FlutterErrorDetails(
          exception: StateError('private-text'),
          stack: StackTrace.fromString(
            '#0 private-text (package:mypet/ui/home_screen.dart:1250:9)',
          ),
        ),
      );
      Telemetry.recordError(StateError('private-text'), StackTrace.current);
      expect(lines, hasLength(9));
      expect(
        lines[3],
        contains(
          'input=$first ball=ready attempts=5 successes=3 stars=1 outcome=success',
        ),
      );
      expect(
        lines[4],
        contains('input=$second ball=none place=home menu_open=false'),
      );
    }, directory: directory);
    expect(lines.first, contains('seq=1 event=session_start'));
    expect(lines[6], contains('event=tab to=diary'));
    expect(
      lines[7],
      contains(
        'event=flutter_error kind=state origin=ui/home_screen.dart:1250',
      ),
    );
    expect(lines.last, contains('event=unhandled_error'));
    expect(lines.join(), isNot(contains('private-text')));
    expect(await File('${directory.path}/play.log').readAsLines(), lines);
    expect(Telemetry.playTraceEnabled, isFalse);
    expect(Telemetry.playTrace(PlayAction.close, PlayPhase.tap), 0);
  });

  test('재실행 뒤에도 직전 파일이 남고 가득 찬 파일은 한 세대만 보관한다', () async {
    final current = File('${directory.path}/play.log');
    final previous = File('${directory.path}/play.previous.log');
    await current.writeAsString('x' * 65535);
    await previous.writeAsString('expired');
    await Telemetry.capturePlayTrace((_) {}, () async {
      Telemetry.playTrace(PlayAction.open, PlayPhase.tap);
    }, directory: directory);
    await Telemetry.capturePlayTrace((_) {}, () async {
      Telemetry.playTrace(PlayAction.close, PlayPhase.tap);
    }, directory: directory);
    final lines = await current.readAsLines();
    expect(
      lines.where((line) => line.contains('seq=1 event=session_start')),
      hasLength(2),
    );
    expect(lines[1], contains('action=open'));
    expect(lines.last, contains('action=close'));
    expect(await previous.readAsString(), 'x' * 65535);
    expect(await current.length(), lessThanOrEqualTo(65536));
  });

  test('사용 기록을 끄면 대기 중 입력과 두 파일을 지우고 후속 탭은 남기지 않는다', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final lines = <String>[];
    final current = File('${directory.path}/play.log');
    final previous = File('${directory.path}/play.previous.log');
    await current.writeAsString('old');
    await previous.writeAsString('older');
    await Telemetry.capturePlayTrace(lines.add, () async {
      Telemetry.playTrace(PlayAction.trick, PlayPhase.tap);
      final off = Telemetry.setUserOff(true);
      expect(Telemetry.playTraceEnabled, isFalse);
      expect(Telemetry.playTrace(PlayAction.close, PlayPhase.tap), 0);
      await off;
      expect(await Telemetry.isUserOff(), isTrue);
    }, directory: directory);
    expect(lines, hasLength(2));
    expect(await current.exists(), isFalse);
    expect(await previous.exists(), isFalse);
  });

  test('기기 출력과 파일 저장 실패가 놀이 입력을 중단시키지 않는다', () async {
    final path = '${directory.path}/occupied';
    await File(path).writeAsString('existing');
    await Telemetry.capturePlayTrace((_) => throw StateError('sink'), () async {
      expect(Telemetry.playTrace(PlayAction.close, PlayPhase.tap), 2);
    }, directory: Directory(path));
    expect(await File(path).readAsString(), 'existing');
  });
}
