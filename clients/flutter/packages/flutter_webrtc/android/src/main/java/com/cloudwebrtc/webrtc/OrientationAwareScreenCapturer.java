package com.cloudwebrtc.webrtc;

import org.webrtc.SurfaceTextureHelper;
import org.webrtc.CapturerObserver;
import org.webrtc.ThreadUtils;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.media.projection.MediaProjection;
import android.os.Build;
import android.view.Surface;
import android.view.WindowManager;
import android.app.Activity;
import android.util.Log;
import android.hardware.display.DisplayManager;
import android.util.DisplayMetrics;
import android.hardware.display.VirtualDisplay;
import android.media.projection.MediaProjectionManager;
import android.view.Display;

/**
 * An copy of ScreenCapturerAndroid to capture the screen content while being aware of device orientation
 */
@TargetApi(21)
public class OrientationAwareScreenCapturer implements VideoCapturer, VideoSink {
    private static final String TAG = "OrientationAwareScreenCapturer";
    private static final int DISPLAY_FLAGS =
            DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC | DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION;
    // DPI for VirtualDisplay, does not seem to matter for us.
    private static final int VIRTUAL_DISPLAY_DPI = 400;
    private final Intent mediaProjectionPermissionResultData;
    private final MediaProjection.Callback mediaProjectionCallback;
    private int width;
    private int height;
    private volatile int oldWidth;
    private volatile int oldHeight;
    private VirtualDisplay virtualDisplay;
    private Surface virtualDisplaySurface;
    private SurfaceTextureHelper surfaceTextureHelper;
    private CapturerObserver capturerObserver;
    private long numCapturedFrames = 0;
    private MediaProjection mediaProjection;
    private volatile boolean isDisposed = false;
    private volatile boolean isStopped = false;
    private volatile boolean capturedContentSizeAuthoritative = false;
    private MediaProjectionManager mediaProjectionManager;
    private WindowManager windowManager;
    private boolean isPortrait;
    private final String trackId;
    private final int maximumDimension;
    private final ScreenCaptureFrameRateGate frameRateGate;
    private final ScreenAudioCapture screenAudioCapture;

    /**
     * Constructs a new Screen Capturer.
     *
     * @param mediaProjectionPermissionResultData the result data of MediaProjection permission
     *                                            activity; the calling app must validate that result code is Activity.RESULT_OK before
     *                                            calling this method.
     **/
    public OrientationAwareScreenCapturer(Intent mediaProjectionPermissionResultData,
                                          String trackId,
                                          int maximumDimension,
                                          int maximumFrameRate,
                                          ScreenAudioCapture screenAudioCapture) {
        this.mediaProjectionPermissionResultData = mediaProjectionPermissionResultData;
        this.trackId = trackId;
        this.maximumDimension = maximumDimension;
        this.frameRateGate = new ScreenCaptureFrameRateGate(maximumFrameRate);
        this.screenAudioCapture = screenAudioCapture;
        this.mediaProjectionCallback = new MediaProjection.Callback() {
            @Override
            public void onStop() {
                super.onStop();
                Log.i(TAG, "projection_system_stop");
                handleProjectionStopped();
            }

            @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            @Override
            public void onCapturedContentVisibilityChanged(boolean isVisible) {
                Log.i(TAG, "projection_content_visibility=" + (isVisible ? "visible" : "hidden"));
                FlutterWebRTCPlugin.notifyMediaProjectionVisibilityChanged(trackId, isVisible);
            }

            @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
            @Override
            public void onCapturedContentResize(int width, int height) {
                if (width <= 0 || height <= 0 || isDisposed || isStopped) return;
                capturedContentSizeAuthoritative = true;
                int[] output = ScreenCaptureDimensions.forOutput(
                        width, height, isDeviceOrientationPortrait(), true, maximumDimension);
                changeCaptureFormat(output[0], output[1], 15);
            }
        };
    }

    public void onFrame(VideoFrame frame) {
        // Silently drop in-flight frames that arrive after stop/dispose.
        // stopCapture() no longer holds the monitor (synchronized removed), so guard explicitly here.
        if (isDisposed || isStopped || !frameRateGate.shouldForward(System.nanoTime())) return;
        this.isPortrait = isDeviceOrientationPortrait();
        final int[] outputDimensions = ScreenCaptureDimensions.forOutput(
                this.width,
                this.height,
                this.isPortrait,
                capturedContentSizeAuthoritative,
                maximumDimension);
        final int newW = outputDimensions[0];
        final int newH = outputDimensions[1];
        // Avoid ANR: only enter changeCaptureFormat() (synchronized) when the dimensions actually change.
        // Previously every frame took the lock, which widened the race window against stopCapture().
        if (newW != this.oldWidth || newH != this.oldHeight) {
            changeCaptureFormat(newW, newH, 15);
        }
        capturerObserver.onFrameCaptured(frame);
    }

    private boolean isDeviceOrientationPortrait() {
        final Display display = windowManager.getDefaultDisplay();
        final DisplayMetrics metrics = new DisplayMetrics();
        display.getRealMetrics(metrics);
        
        return metrics.heightPixels > metrics.widthPixels;
    }


    private void checkNotDisposed() {
        if (isDisposed) {
            throw new RuntimeException("capturer is disposed.");
        }
    }

    public synchronized void initialize(final SurfaceTextureHelper surfaceTextureHelper,
                                        final Context applicationContext, final CapturerObserver capturerObserver) {
        checkNotDisposed();
        if (capturerObserver == null) {
            throw new RuntimeException("capturerObserver not set.");
        }
        this.capturerObserver = capturerObserver;
        if (surfaceTextureHelper == null) {
            throw new RuntimeException("surfaceTextureHelper not set.");
        }
        this.surfaceTextureHelper = surfaceTextureHelper;

        this.windowManager = (WindowManager) applicationContext.getSystemService(
                Context.WINDOW_SERVICE);
        this.mediaProjectionManager = (MediaProjectionManager) applicationContext.getSystemService(
                Context.MEDIA_PROJECTION_SERVICE);
    }

    @Override
    public synchronized void startCapture(
            final int width, final int height, final int ignoredFramerate) {
        //checkNotDisposed();

        this.isPortrait = isDeviceOrientationPortrait();
        int[] output = ScreenCaptureDimensions.forOutput(
                width, height, this.isPortrait, false, maximumDimension);
        this.width = output[0];
        this.height = output[1];
        this.oldWidth = this.width;
        this.oldHeight = this.height;
        frameRateGate.reset();

        mediaProjection = mediaProjectionManager.getMediaProjection(
                Activity.RESULT_OK, mediaProjectionPermissionResultData);

        // Let MediaProjection callback use the SurfaceTextureHelper thread.
        mediaProjection.registerCallback(mediaProjectionCallback, surfaceTextureHelper.getHandler());

        createVirtualDisplay();
        if (screenAudioCapture != null && !screenAudioCapture.start(mediaProjection)) {
            Log.i(TAG, "screen_audio_capture_unavailable");
        }
        Log.i(TAG, "projection_capture_started display=" + (virtualDisplay != null ? "ready" : "unavailable"));
        capturerObserver.onCapturerStarted(true);
        surfaceTextureHelper.startListening(this);
    }

    @Override
    public void stopCapture() {
        // synchronized removed: stopCapture() used to hold the capturer monitor while
        // waiting on the SurfaceTextureHelper thread via invokeAtFrontUninterruptibly, while
        // that same thread's onFrame() -> changeCaptureFormat() (synchronized) tried to
        // re-enter the same monitor, causing a deadlock (ANR).
        if (isDisposed || isStopped) return;
        Log.i(TAG, "projection_app_stop");
        isStopped = true;
        ThreadUtils.invokeAtFrontUninterruptibly(surfaceTextureHelper.getHandler(), new Runnable() {
            @Override
            public void run() {
                surfaceTextureHelper.stopListening();
                capturerObserver.onCapturerStopped();
                if (screenAudioCapture != null) screenAudioCapture.stop();
                if (virtualDisplay != null) {
                    virtualDisplay.release();
                    virtualDisplay = null;
                }
                releaseVirtualDisplaySurface();
                if (mediaProjection != null) {
                    // Unregister the callback before stopping, otherwise the callback recursively
                    // calls this method.
                    mediaProjection.unregisterCallback(mediaProjectionCallback);
                    mediaProjection.stop();
                    mediaProjection = null;
                }
            }
        });
    }

    private void handleProjectionStopped() {
        if (isDisposed || isStopped) return;
        Log.i(TAG, "projection_capture_ended_by_system");
        isStopped = true;
        surfaceTextureHelper.stopListening();
        capturerObserver.onCapturerStopped();
        if (screenAudioCapture != null) screenAudioCapture.stop();
        if (virtualDisplay != null) {
            virtualDisplay.release();
            virtualDisplay = null;
        }
        releaseVirtualDisplaySurface();
        mediaProjection = null;
        FlutterWebRTCPlugin.notifyMediaProjectionStopped(trackId);
    }

    @Override
    public synchronized void dispose() {
        isDisposed = true;
        if (screenAudioCapture != null) screenAudioCapture.dispose();
    }

    /**
     * Changes output video format. This method can be used to scale the output
     * video, or to change orientation when the captured screen is rotated for example.
     *
     * @param width            new output video width
     * @param height           new output video height
     * @param ignoredFramerate ignored
     */
    @Override
    public synchronized void changeCaptureFormat(
            final int width, final int height, final int ignoredFramerate) {
        checkNotDisposed();
        if (this.oldWidth != width || this.oldHeight != height) {
            this.width = width;
            this.height = height;
            this.oldWidth = width;
            this.oldHeight = height;

            ThreadUtils.invokeAtFrontUninterruptibly(surfaceTextureHelper.getHandler(), new Runnable() {
                @Override
                public void run() {
                    if (surfaceTextureHelper == null || mediaProjection == null) {
                        return;
                    }

                    if (virtualDisplay != null) {
                        resizeVirtualDisplay();
                    } else {
                        createVirtualDisplay();
                    }
                }
            });
        }
    }

    private void createVirtualDisplay() {
        updateSurfaceTextureSize();
        releaseVirtualDisplaySurface();
        virtualDisplaySurface = new Surface(surfaceTextureHelper.getSurfaceTexture());
        virtualDisplay = mediaProjection.createVirtualDisplay("WebRTC_ScreenCapture", width, height,
                VIRTUAL_DISPLAY_DPI, DISPLAY_FLAGS, virtualDisplaySurface,
                null /* callback */, null /* callback handler */);
    }

    private void resizeVirtualDisplay() {
        updateSurfaceTextureSize();
        virtualDisplay.resize(width, height, VIRTUAL_DISPLAY_DPI);
        final Surface oldSurface = virtualDisplaySurface;
        virtualDisplaySurface = new Surface(surfaceTextureHelper.getSurfaceTexture());
        virtualDisplay.setSurface(virtualDisplaySurface);
        if (oldSurface != null) {
            oldSurface.release();
        }
    }

    private void updateSurfaceTextureSize() {
        surfaceTextureHelper.setTextureSize(width, height);
        surfaceTextureHelper.getSurfaceTexture().setDefaultBufferSize(width, height);
    }

    private void releaseVirtualDisplaySurface() {
        if (virtualDisplaySurface != null) {
            virtualDisplaySurface.release();
            virtualDisplaySurface = null;
        }
    }

    @Override
    public boolean isScreencast() {
        return true;
    }

    public long getNumCapturedFrames() {
        return numCapturedFrames;
    }
}
