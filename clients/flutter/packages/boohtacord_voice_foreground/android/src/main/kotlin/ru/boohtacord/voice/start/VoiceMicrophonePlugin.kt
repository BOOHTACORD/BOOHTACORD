package ru.boohtacord.voice.start

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VoiceMicrophonePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var playbackPlugin: VoicePlaybackPlugin? = null
    private val visibility = Visibility()
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "boohtacord/voice_microphone")
        channel.setMethodCallHandler(this)
        (context as Application).registerActivityLifecycleCallbacks(visibility)
        playbackPlugin = VoicePlaybackPlugin(context, binding.binaryMessenger, visibility)
        MicrophoneService.stopped = { channel.invokeMethod("stopped", null) }
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canStart" -> result.success(MicrophoneService.active || visibility.visible)
            "start" -> start(result)
            "stop" -> { stop(); result.success(true) }
            else -> result.notImplemented()
        }
    }
    private fun start(result: MethodChannel.Result) {
        val granted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (!AdmissionPolicy.permitsStart(MicrophoneService.active, visibility.visible, granted)) {
            result.success(false); return
        }
        if (MicrophoneService.active) { result.success(true); return }
        if (pending != null) { result.success(false); return }
        pending = result
        MicrophoneService.ready = { success -> pending?.success(success); pending = null }
        try {
            val intent = Intent(context, MicrophoneService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
            handler.postDelayed({ if (pending === result) stop() }, 4000)
        } catch (_: Exception) { stop() }
    }
    private fun stop() {
        pending?.success(false); pending = null; MicrophoneService.ready = null
        MicrophoneService.expectedStop = true; MicrophoneService.active = false
        context.stopService(Intent(context, MicrophoneService::class.java))
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { visibility.attach(binding.activity) }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { visibility.attach(binding.activity) }
    override fun onDetachedFromActivityForConfigChanges() { visibility.detach() }
    override fun onDetachedFromActivity() {
        visibility.detach()
        playbackPlugin?.stop()
        stop()
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        playbackPlugin?.dispose(); playbackPlugin = null
        stop(); MicrophoneService.stopped = null; handler.removeCallbacksAndMessages(null)
        (context as Application).unregisterActivityLifecycleCallbacks(visibility)
        channel.setMethodCallHandler(null)
    }
}
