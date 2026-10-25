package ru.boohtacord.app

import android.app.Activity
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Rect
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "boohtacord/download"
    private val screenShareChannelName = "boohtacord/screen_share"
    private val audioDevicesChannelName = "boohtacord/audio_devices"
    private val systemGesturesChannelName = "boohtacord/system_gestures"
    private val usbOutputRoutePrefix = "android-usb-route:"
    private val communicationOutputRoutePrefix = "android-communication-route:"
    private val backgroundServiceClassName =
        "de.julianassmann.flutter_background.IsolateHolderService"
    private val requestCode = 7641
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var excludeLeftEdgeSwipe = false
    private var excludeRightEdgeSwipe = false
    private var gestureExclusionView: View? = null

    @Suppress("DEPRECATION")
    private fun screenShareServiceDeclaresMediaProjectionType(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return try {
            val serviceInfo = packageManager.getServiceInfo(
                ComponentName(packageName, backgroundServiceClassName),
                PackageManager.GET_META_DATA,
            )
            (serviceInfo.foregroundServiceType and
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION) != 0
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ru.boohtacord.app.notifications.PushSupport.register(this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemGesturesChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "setEdges") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                excludeLeftEdgeSwipe = call.argument<Boolean>("left") ?: false
                excludeRightEdgeSwipe = call.argument<Boolean>("right") ?: false
                updateSystemGestureExclusionRects()
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSaveResult != null) {
                    result.error("SAVE_IN_PROGRESS", "A save dialog is already open.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("filename")
                val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes == null || name.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "File name and bytes are required.", null)
                    return@setMethodCallHandler
                }
                pendingBytes = bytes
                pendingSaveResult = result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, requestCode)
                } catch (error: Exception) {
                    pendingBytes = null
                    pendingSaveResult = null
                    result.error("SAVE_FAILED", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenShareChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "awaitForegroundService") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val timeoutMs = (call.argument<Int>("timeoutMs") ?: 3000)
                    .coerceIn(250, 5000)
                val startedAt = SystemClock.elapsedRealtime()
                val activityManager =
                    getSystemService(ACTIVITY_SERVICE) as ActivityManager
                val serviceSupportsCapture =
                    screenShareServiceDeclaresMediaProjectionType()

                fun checkForegroundState() {
                    val isForeground = serviceSupportsCapture &&
                        activityManager.getRunningServices(Int.MAX_VALUE).any { service ->
                            service.service.className == backgroundServiceClassName &&
                                service.foreground
                        }
                    if (isForeground) {
                        result.success(true)
                    } else if (SystemClock.elapsedRealtime() - startedAt >= timeoutMs) {
                        result.success(false)
                    } else {
                        mainHandler.postDelayed(::checkForegroundState, 50)
                    }
                }

                checkForegroundState()
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioDevicesChannelName)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "enumerateAudioDevices" -> {
                        val usbTypes = setOf(
                            AudioDeviceInfo.TYPE_USB_DEVICE,
                            AudioDeviceInfo.TYPE_USB_HEADSET,
                        )
                        val devices = mutableListOf<Map<String, String>>()

                        val inputs = audioManager
                            .getDevices(AudioManager.GET_DEVICES_INPUTS)
                            .filter { it.type in usbTypes }
                        inputs.forEachIndexed { index, device ->
                            devices += mapOf(
                                "deviceId" to device.id.toString(),
                                "kind" to "audioinput",
                                "label" to device.productName.toString().ifBlank {
                                    "USB-микрофон ${index + 1}"
                                },
                                "groupId" to "usb:${device.id}",
                            )
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.availableCommunicationDevices
                                .filter { it.isSink }
                                .forEachIndexed { index, device ->
                                    val prefix = if (device.type in usbTypes) {
                                        usbOutputRoutePrefix
                                    } else {
                                        communicationOutputRoutePrefix
                                    }
                                    devices += mapOf(
                                        "deviceId" to prefix + device.id,
                                        "kind" to "audiooutput",
                                        "label" to communicationDeviceLabel(device, index),
                                        "groupId" to "android:${device.id}",
                                    )
                                }
                        }
                        result.success(devices)
                    }
                    "mapRecorderInputDevice" -> {
                        val requestedId = call.argument<String>("deviceId")
                        val input = audioManager
                            .getDevices(AudioManager.GET_DEVICES_INPUTS)
                            .firstOrNull { webRtcInputDeviceId(it) == requestedId }
                        result.success(input?.id?.toString())
                    }
                    "selectCommunicationOutput" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val requestedId = call.argument<String>("deviceId")
                            ?.toIntOrNull()
                        val route = audioManager.availableCommunicationDevices
                            .firstOrNull { it.id == requestedId && it.isSink }
                        result.success(route != null && audioManager.setCommunicationDevice(route))
                    }
                    "clearCommunicationOutput" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.clearCommunicationDevice()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPostResume() {
        super.onPostResume()
        // Use the full-window view so the exclusion rects line up with the
        // physical display edges even when the content view is inset by the
        // status/navigation bars or display cutouts.
        val root = window.decorView
        if (gestureExclusionView !== root) {
            gestureExclusionView?.removeOnLayoutChangeListener(gestureExclusionLayoutListener)
            gestureExclusionView = root
            root.addOnLayoutChangeListener(gestureExclusionLayoutListener)
        }
        updateSystemGestureExclusionRects()
    }

    private val gestureExclusionLayoutListener =
        View.OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            updateSystemGestureExclusionRects()
        }

    private fun updateSystemGestureExclusionRects() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val view = gestureExclusionView ?: window.decorView
        gestureExclusionView = view
        if (view.width <= 0 || view.height <= 0) return

        val density = resources.displayMetrics.density
        val edgeWidth = (24 * density).toInt().coerceAtLeast(1)
        val exclusionHeight = (200 * density).toInt().coerceAtMost(view.height)
        val top = ((view.height - exclusionHeight) / 2).coerceAtLeast(0)
        val bottom = (top + exclusionHeight).coerceAtMost(view.height)
        val rects = mutableListOf<Rect>()
        if (excludeLeftEdgeSwipe) {
            rects += Rect(0, top, edgeWidth.coerceAtMost(view.width), bottom)
        }
        if (excludeRightEdgeSwipe) {
            rects += Rect(
                (view.width - edgeWidth).coerceAtLeast(0),
                top,
                view.width,
                bottom,
            )
        }
        view.systemGestureExclusionRects = rects
    }

    @Deprecated("Deprecated in Android, retained for Flutter activity result routing")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pendingSaveResult ?: return
        val bytes = pendingBytes
        pendingSaveResult = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        val uri: Uri? = data?.data
        if (uri == null || bytes == null) {
            result.error("SAVE_FAILED", "The document provider returned no file.", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { output -> output.write(bytes) }
                ?: throw IllegalStateException("Could not open the selected document.")
            result.success(true)
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message, null)
        }
    }

    private fun communicationDeviceLabel(device: AudioDeviceInfo, index: Int): String {
        val productName = device.productName.toString().trim()
        return when (device.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Динамик телефона"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Разговорный динамик"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> productName.ifBlank {
                "Проводная гарнитура"
            }
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> productName.ifBlank {
                "Проводные наушники"
            }
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> productName.ifBlank {
                "Bluetooth-гарнитура"
            }
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET -> productName.ifBlank {
                "USB-аудиоустройство ${index + 1}"
            }
            else -> productName.ifBlank { "Аудиоустройство ${index + 1}" }
        }
    }

    private fun webRtcInputDeviceId(device: AudioDeviceInfo): String = when (device.type) {
        AudioDeviceInfo.TYPE_BUILTIN_MIC -> "microphone-${device.address}"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired-headset"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
        else -> device.id.toString()
    }
}
