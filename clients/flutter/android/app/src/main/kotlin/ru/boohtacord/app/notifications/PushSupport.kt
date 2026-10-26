package ru.boohtacord.app.notifications

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object PushSupport {
    private const val channelId = "boohtacord_remote_v1"
    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "boohtacord/notifications")
            .setMethodCallHandler { call, result ->
                val manager = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "prepare" -> {
                        val available = try {
                            val api = Class.forName("com.google.android.gms.common.GoogleApiAvailability")
                            val instance = api.getMethod("getInstance").invoke(null)
                            api.getMethod("isGooglePlayServicesAvailable", Context::class.java)
                                .invoke(instance, activity) == 0
                        } catch (_: Exception) { false }
                        if (available && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = NotificationChannel(channelId, "Сообщения BOOHTACORD", NotificationManager.IMPORTANCE_DEFAULT)
                            channel.description = "Нейтральные уведомления о сообщениях и упоминаниях"
                            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                            channel.setShowBadge(false)
                            manager.createNotificationChannel(channel)
                        }
                        result.success(if (available) "available" else "unavailable")
                    }
                    "clearRemoteCards" -> {
                        val binding = call.argument<String>("binding_ref")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            manager.activeNotifications.filter { binding != null && it.notification.channelId == channelId && it.tag?.startsWith("bcn:$binding:") == true }
                                .forEach { manager.cancel(it.tag, it.id) }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
