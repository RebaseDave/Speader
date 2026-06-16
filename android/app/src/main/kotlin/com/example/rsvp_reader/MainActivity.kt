package com.example.rsvp_reader

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rsvp_reader/volume_keys"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                methodChannel?.invokeMethod("volumeUp", null)
                true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                methodChannel?.invokeMethod("volumeDown", null)
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}