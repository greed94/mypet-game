import 'dart:convert';
import 'dart:io';

import '../data/database.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';

/// 테스트 빌드 전용 연습 모드. 켜면 지금 펫을 복사한 연습 펫(mypet_test DB)으로 바꾸고,
/// 그 펫의 시계만 앞으로 보낼 수 있다. 진짜 펫의 기록과 시계는 그대로 둔다.
class TestMode {
  TestMode(
    this._file, {
    this.on = false,
    this.offset = Duration.zero,
    File? stagingFile,
  }) : _stagingFile = stagingFile ?? File('${_file.path}.next');

  /// 상태를 적어 두는 파일(앱 문서 폴더의 test_mode.json). 앱을 다시 켜도 연습 펫과 보낸 시간이 이어진다.
  final File _file;
  final File _stagingFile;
  bool on;

  /// 실제 시각보다 앞선 만큼. 앞으로만 간다.
  Duration offset;

  static const realDb = AppDatabase.realName;
  static const testDb = AppDatabase.practiceName;

  String get dbName => on ? testDb : realDb;

  DateTime now() => on ? DateTime.now().add(offset) : DateTime.now();

  static Future<TestMode> load(File file) async {
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final micros = j['offsetMicroseconds'];
      return TestMode(
        file,
        on: j['on'] == true,
        offset: micros is int
            ? Duration(microseconds: micros)
            : Duration(minutes: (j['offsetMinutes'] as num? ?? 0).toInt()),
      );
    } on Object {
      return TestMode(file);
    }
  }

  /// 실제 기록을 [testPath]에 통째로 복사한다. 새 DB가 열리는 것을 확인한 뒤 select로 전환한다.
  static Future<void> copyForPractice(AppDatabase real, String testPath) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('$testPath$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await real.customStatement('VACUUM INTO ?', [testPath]);
  }

  // 기록이 중간에 끊겨도 다음 실행이 마지막으로 완전히 저장된 상태를 읽도록 한다.
  Future<void> _persist(bool practice, Duration ahead) async {
    await _stagingFile.writeAsString(
      jsonEncode({
        'on': practice,
        'offsetMinutes': ahead.inMinutes,
        'offsetMicroseconds': ahead.inMicroseconds,
      }),
      flush: true,
    );
    await _stagingFile.rename(_file.path);
  }

  /// 파일을 쓰지 못하면 현재 펫과 시계를 유지해 다시 시도할 수 있다.
  Future<void> select(bool practice) async {
    await _persist(practice, Duration.zero);
    on = practice;
    offset = Duration.zero;
  }

  /// 산책 중이나 카페·가게·병원에 있을 땐 시간을 보내지 않는다. 그 장소엔 돌아올 시각이 없어
  /// 몇 날을 거기 갇혀 있던 걸로 남는다. 유치원에 맡긴 동안은 하원 버스가 있어 된다.
  static bool canJump(PetController c) => !c.walking && (!c.out || c.inDaycare);

  /// 앱을 [d]만큼 뒤에 다시 연 것처럼: 지금 상태를 저장하고, 시계를 보내고, 다시 깨운다.
  /// 반김·하원 버스·쉬 신호·어제 일기가 실제로 그만큼 지난 것처럼 돈다.
  Future<void> jump(PetController c, Duration d) async {
    if (!on || d <= Duration.zero || !canJump(c)) return;
    final next = offset + d;
    await _persist(on, next);
    // 여기부터 wake까지 await가 없어야 한다. 사이에 게임 tick이 앞당긴 시계로 하원·저장을 먼저 하면
    // 보낸 시간이 통째로 사라진다.
    c.sleepApp();
    offset = next;
    c.wake();
  }
}

/// [now]에서 다음 [hour]시 정각까지. 지금이 그 시각이거나 지났으면 다음 날.
Duration untilHour(DateTime now, int hour) {
  var t = DateTime(now.year, now.month, now.day, hour);
  if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
  return t.difference(now);
}

/// 새벽 5시부터 시작하는 다음 펫 생활일의 아침 9시까지.
Duration untilNextPetMorning(DateTime now) {
  final day = petDate(now);
  return DateTime(day.year, day.month, day.day + 1, 9).difference(now);
}

/// 띠에 보일 앞선 정도. "+2일 3시간"처럼.
String aheadLabel(Duration d) {
  if (d.inMinutes < 1) return '실제 시각';
  final days = d.inDays, hours = d.inHours % 24, minutes = d.inMinutes % 60;
  return [
    if (days > 0) '$days일',
    if (hours > 0) '$hours시간',
    if (days == 0 && hours == 0 && minutes > 0) '$minutes분',
  ].join(' ').replaceFirst(RegExp('^'), '+');
}
