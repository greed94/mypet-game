import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 아침·저녁 하루 두 번, 펫 시점 문구로. 정확한 시각이 필요 없어서 특별 권한이 없는 inexact 모드를 쓴다.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _morning = 1, _evening = 2;

  /// 알림을 눌러 앱을 열면 갈 곳('diary' 또는 'home'). 홈 화면이 듣고 탭을 옮긴 뒤 비운다.
  static final opened = ValueNotifier<String?>(null);

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _open,
    );
    // 꺼져 있던 앱을 알림으로 켜면 위 콜백 대신 여기로 온다.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      _open(response);
    }
  }

  /// 아침 알림은 어제 일기(앱을 열 때 쓴다)로, 저녁 알림("오늘 어땠어?")은 말을 걸 수 있는 홈으로.
  /// 이미 예약된 알림에는 payload가 없어서 알림 번호로 가른다.
  static void _open(NotificationResponse r) =>
      opened.value = r.id == _morning ? 'diary' : 'home';

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// 처음부터 다시 만들면 옛 이름으로 부르는 알림과, 그걸 눌러 남은 이동 요청을 모두 지운다.
  static Future<void> cancelAll() async {
    opened.value = null;
    await _plugin.cancelAll();
  }

  static Future<void> scheduleDaily(String petName) async {
    await _plugin.cancelAll();
    // 펫 목소리로 부른다. 기다린다·배고프다처럼 미안하게 만드는 말은 쓰지 않는다.
    await _schedule(_morning, 8, 30, petName, '좋은 아침! 나 일어났어.');
    await _schedule(_evening, 21, 0, petName, '오늘 어땠어? 들려줄래?');
  }

  static Future<void> _schedule(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily',
          '하루 알림',
          channelDescription: '아침과 저녁에 펫이 부르는 알림',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
