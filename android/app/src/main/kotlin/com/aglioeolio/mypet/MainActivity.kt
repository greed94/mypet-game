package com.aglioeolio.mypet

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.ActivityNotFoundException
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mypet/crisis_support")
            .setMethodCallHandler { call, result ->
                if (call.method == "dial109") {
                    try {
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:109")))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    } catch (_: SecurityException) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
        // 무음·진동 모드에서는 짖지 않고 진동만 하도록 Sfx가 벨소리 모드를 묻는다. 0 무음, 1 진동, 2 소리.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mypet/audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "ringerMode") {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(audio.ringerMode)
                } else {
                    result.notImplemented()
                }
            }
    }
}
