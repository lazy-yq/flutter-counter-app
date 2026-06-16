// filename: android/app/src/main/kotlin/com/counter/flutter_app/CloseActionReceiver.kt
// 广播接收器 - 接收通知栏"关闭"按钮的广播，停止前台服务并通知 Flutter 关闭悬浮窗

package com.counter.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class CloseActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == CounterForegroundService.ACTION_CLOSE) {
            // 停止前台通知服务
            context.stopService(Intent(context, CounterForegroundService::class.java))

            // 通过 MethodChannel 通知 Flutter 关闭悬浮窗
            MainActivity.instance?.let { activity ->
                val channel = MethodChannel(
                    activity.flutterEngine!!.dartExecutor.binaryMessenger,
                    MainActivity.CHANNEL
                )
                channel.invokeMethod("onCloseFromNotification", null)
            }
        }
    }
}