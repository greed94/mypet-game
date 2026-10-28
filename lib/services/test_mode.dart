import 'dart:convert';
import 'dart:io';

import '../data/database.dart';
import '../pet/pet_controller.dart';

/// 테스트 빌드 전용 연습 모드. 켜면 지금 펫을 복사한 연습 펫(mypet_test DB)으로 바꾸고,
/// 그 펫의 시계만 앞으로 보낼 수 있다. 진짜 펫의 기록과 시계는 그대로 둔다.
class TestMode {
  TestMode(this._file, {this.on = false, this.offset = Duration.zero});

  /// 상태를 적어 두는 파일(앱 문서 폴더의 test_mode.json). 앱을 다시 켜도 연습 펫과 보낸 시간이 이어진다.
  final File _file;
  bool on;

  /// 실제 시각보다 앞선 만큼. 앞으로만 간다.
  Duration offset;

  static const realDb = 'mypet';
  static const testDb = 'mypet_test';

  String get dbName => on ? testDb : realDb;

  DateTime now() => on ? DateTime.now().add(offset) : DateTime.now();

  static Future<TestMode> load(File file) async {
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      return TestMode(
        file,
        on: j['on'] == true,
        offset: Duration(minutes: (j['offsetMinutes'] as num? ?? 0).toInt()),
      );
    } on Object {
      return TestMode(file);
    }
  }

  Future<void> _save() => _file.writeAsString(
    jsonEncode({'on': on, 'offsetMinutes': offset.inMinutes}),
  );

  /// 연습 펫으로 바꾼다. [real]을 [testPath]로 통째로 복사한다(열려 있는 채로 일관된 사본이 된다).
  Future<void> enter(AppDatabase real, String testPath) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('$testPath$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await real.customStatement('VACUUM INTO ?', [testPath]);
    on = true;
    offset = Duration.zero;
    await _save();
  }

  Future<void> leave() async {
    on = false;
    offset = Duration.zero;
    await _save();
  }

  /// 산책 중이나 카페·가게·병원에 있을 땐 시간을 보내지 않는다. 그 장소엔 돌아올 시각이 없어
  /// 몇 날을 거기 갇혀 있던 걸로 남는다. 유치원에 맡긴 동안은 하원 버스가 있어 된다.
  static bool canJump(PetController c) => !c.walking && (!c.out || c.inDaycare);

  /// 앱을 [d]만큼 뒤에 다시 연 것처럼: 지금 상태를 저장하고, 시계를 보내고, 다시 깨운다.
  /// 반김·하원 버스·쉬 신호·어제 일기가 실제로 그만큼 지난 것처럼 돈다.
  Future<void> jump(PetController c, Duration d) async {
    if (!on || d <= Duration.zero || !canJump(c)) return;
    final next = offset + d;
    await _file.writeAsString(
      jsonEncode({'on': on, 'offsetMinutes': next.inMinutes}),
    );
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
