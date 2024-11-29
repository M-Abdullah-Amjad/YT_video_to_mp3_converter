package com.example.youtube_to_mp3

import android.media.MediaScannerConnection
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.youtube_to_mp3/mediaplayer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val filePath = call.argument<String>("path")
                if (filePath != null) {
                    MediaScannerConnection.scanFile(this, arrayOf(filePath), null, null)
                    result.success(null)
                } else {
                    result.error("UNAVAILABLE", "File path not provided.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
