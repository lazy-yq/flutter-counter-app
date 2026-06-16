package com.counter.flutter_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "counter/foreground"
        var instance: MainActivity? = null
        var binaryMessenger: BinaryMessenger? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        binaryMessenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForeground" -> {
                        val count = call.argument<Int>("count") ?: 0
                        startCounterForegroundService(count)
                        result.success(true)
                    }
                    "updateCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        CounterForegroundService.updateNotification(this, count)
                        result.success(true)
                    }
                    "stopForeground" -> {
                        stopCounterForegroundService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startCounterForegroundService(count: Int) {
        val intent = Intent(this, CounterForegroundService::class.java).apply {
            putExtra("count", count)
        }
        startForegroundService(intent)
    }

    private fun stopCounterForegroundService() {
        val intent = Intent(this, CounterForegroundService::class.java)
        stopService(intent)
    }

    override fun onDestroy() {
        instance = null
        binaryMessenger = null
        super.onDestroy()
    }
}