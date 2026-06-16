// filename: android/app/src/main/kotlin/com/counter/flutter_app/CounterForegroundService.kt
// 自定义前台服务 - 显示带"关闭"按钮的不可取消通知，同时更新计数信息

package com.counter.flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class CounterForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "counter_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_CLOSE = "com.counter.flutter_app.ACTION_CLOSE_FOREGROUND"

        /** 更新通知中的计数文本 */
        fun updateNotification(context: Context, count: Int) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, count))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val count = intent?.getIntExtra("count", 0) ?: 0
        val notification = buildNotification(this, count)

        // 启动前台服务，显示不可取消的常驻通知
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    /** 创建通知渠道（Android 8.0+ 必需） */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "计数器前台服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "显示计数器悬浮窗的运行状态"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object Builder {
        /** 构建前台服务通知 */
        fun buildNotification(context: Context, count: Int): Notification {
            // "关闭"按钮的 PendingIntent -> 发送广播给 CloseActionReceiver
            val closeIntent = Intent(context, CloseActionReceiver::class.java).apply {
                action = ACTION_CLOSE
            }
            val closePendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                closeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 点击通知回到主页面
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            val launchPendingIntent = PendingIntent.getActivity(
                context,
                1,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("计数器悬浮窗正在运行")
                .setContentText("当前计数: $count")
                .setOngoing(true)           // 不可滑动取消
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(launchPendingIntent)
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "关闭",
                    closePendingIntent
                )
                .build()
        }
    }
}