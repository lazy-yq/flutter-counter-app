// filename: android/app/src/main/kotlin/com/counter/flutter_app/MainActivity.kt
// Flutter 主 Activity - 注册 MethodChannel 用于控制前台通知服务

package com.counter.flutter_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "counter/foreground"
        var instance: MainActivity? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this

        // 注册 MethodChannel，用于 Flutter 与 Android 原生通信
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 启动前台通知服务
                    "startForeground" -> {
                        val count = call.argument<Int>("count") ?: 0
                        startCounterForegroundService(count)
                        result.success(true)
                    }
                    // 更新通知中的计数
                    "updateCount" -> {
                        val count = call.argument<Int>("count") ?: 0
                        CounterForegroundService.updateNotification(this, count)
                        result.success(true)
                    }
                    // 停止前台通知服务
                    "stopForeground" -> {
                        stopCounterForegroundService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 启动计数器前台服务 */
    private fun startCounterForegroundService(count: Int) {
        val intent = Intent(this, CounterForegroundService::class.java).apply {
            putExtra("count", count)
        }
        startForegroundService(intent)
    }

    /** 停止计数器前台服务 */
    private fun stopCounterForegroundService() {
        val intent = Intent(this, CounterForegroundService::class.java)
        stopService(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}