package com.counter.flutter_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class CloseActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == CounterForegroundService.ACTION_CLOSE) {
            context.stopService(Intent(context, CounterForegroundService::class.java))

            MainActivity.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, MainActivity.CHANNEL)
                    .invokeMethod("onCloseFromNotification", null)
            }
        }
    }
}