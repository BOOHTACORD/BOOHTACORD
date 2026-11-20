package ru.boohtacord.voice.start

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class MicrophoneService : Service() {
    companion object {
        var active = false
        var expectedStop = false
        var ready: ((Boolean) -> Unit)? = null
        var stopped: (() -> Unit)? = null
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) { stopSelf(); return START_NOT_STICKY }
        try {
            val notification = VoiceNotification.create(this, microphoneActive = true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                startForeground(VoiceNotification.ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else { startForeground(VoiceNotification.ID, notification) }
            expectedStop = false; active = true
            VoiceNotification.refresh(this)
            ready?.invoke(true); ready = null
        } catch (_: Exception) {
            active = false; expectedStop = true; ready?.invoke(false); ready = null; stopSelf()
        }
        return START_NOT_STICKY
    }
    override fun onTaskRemoved(rootIntent: Intent?) { expectedStop = false; stopSelf() }
    override fun onDestroy() {
        active = false; ready?.invoke(false); ready = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_DETACH)
        if (VoicePlaybackService.active) VoiceNotification.refresh(this)
        else VoiceNotification.remove(this)
        if (!expectedStop) stopped?.invoke()
        super.onDestroy()
    }
}
