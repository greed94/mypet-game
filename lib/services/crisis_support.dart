import 'package:flutter/services.dart';

/// 전화 연결은 번호가 채워진 다이얼 화면까지만 연다. 자동 발신하지 않는다.
class CrisisSupport {
  static const _channel = MethodChannel('mypet/crisis_support');

  static Future<bool> openDialer() async {
    try {
      return await _channel.invokeMethod<bool>('dial109') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
