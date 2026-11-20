package ru.boohtacord.voice.start

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class VoicePlaybackPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
    private val visibility: Visibility,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "boohtacord/voice_playback")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
        VoicePlaybackService.stopped = { channel.invokeMethod("stopped", null) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canStart" -> result.success(
                VoicePlaybackAdmissionPolicy.permitsStart(
                    VoicePlaybackService.active,
                    visibility.visible,
                ),
            )
            "start" -> start(result)
            "stop" -> { stop(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    private fun start(result: MethodChannel.Result) {
        if (!VoicePlaybackAdmissionPolicy.permitsStart(
                VoicePlaybackService.active,
                visibility.visible,
            )
        ) {
            result.success(false)
            return
        }
        if (VoicePlaybackService.active) { result.success(true); return }
        if (pending != null) { result.success(false); return }
        pending = result
        VoicePlaybackService.ready = { success -> pending?.success(success); pending = null }
        try {
            val intent = Intent(context, VoicePlaybackService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
            handler.postDelayed({ if (pending === result) stop() }, 4000)
        } catch (_: Exception) {
            stop()
        }
    }

    fun stop() {
        pending?.success(false)
        pending = null
        VoicePlaybackService.ready = null
        VoicePlaybackService.expectedStop = true
        VoicePlaybackService.active = false
        context.stopService(Intent(context, VoicePlaybackService::class.java))
    }

    fun dispose() {
        stop()
        VoicePlaybackService.stopped = null
        handler.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
    }
}
