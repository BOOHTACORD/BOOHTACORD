package com.cloudwebrtc.webrtc.screen.refresh;

import android.os.Build;
import android.os.Handler;
import android.util.Log;
import org.webrtc.CapturerObserver;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoFrame;

/** Makes an already captured stationary image available to a ready/late encoder. */
public final class TextureFrameRefresh {
    public interface Active { boolean get(); }
    private static final String TAG = "ScreenFrameRefresh";
    private final SurfaceTextureHelper texture;
    private final CapturerObserver observer;
    private final Active active;
    private final Handler handler;
    private final StationaryFrameRefresh refresh;
    private final FrameTimestamp timestamps = new FrameTimestamp();
    private long sourceTimestamp, captured, sources, forwarded, requests, started;
    private boolean running;

    public TextureFrameRefresh(SurfaceTextureHelper texture, CapturerObserver observer, Active active) {
        this.texture = texture;
        this.observer = observer;
        this.active = active;
        handler = texture.getHandler();
        refresh = new StationaryFrameRefresh(new StationaryFrameRefresh.Scheduler() {
            public void postDelayed(Runnable task, long delay) { handler.postDelayed(task, delay); }
            public void remove(Runnable task) { handler.removeCallbacks(task); }
        }, () -> System.nanoTime() / 1_000_000, this::requestFrame);
    }

    public void start() {
        handler.post(() -> {
            if (!active.get()) return;
            captured = sources = forwarded = requests = 0;
            sourceTimestamp = Long.MIN_VALUE;
            started = System.nanoTime();
            timestamps.reset();
            running = true;
            refresh.start();
            // Android 14+ reports visibility. Never refresh before that confirmation.
            refresh.setVisible(Build.VERSION.SDK_INT < 34);
        });
    }

    public void setVisible(boolean visible) { refresh.setVisible(visible); }

    public void frameArrived(long timestamp) {
        captured++;
        if (timestamp == sourceTimestamp) return; // A forced delivery is not a new source frame.
        sourceTimestamp = timestamp;
        sources++;
        refresh.frameArrived();
        if (sources == 1) log("source_first");
    }

    public void forward(VideoFrame frame) {
        long timestamp = timestamps.next(frame.getTimestampNs(), System.nanoTime());
        frame.getBuffer().retain();
        VideoFrame delivery = new VideoFrame(frame.getBuffer(), frame.getRotation(), timestamp);
        try {
            observer.onFrameCaptured(delivery);
            if (++forwarded == 1) log("forward_first");
        } finally {
            delivery.release();
        }
    }

    private void requestFrame() {
        if (!active.get()) { stop(); return; }
        requests++;
        if ((requests & (requests - 1)) == 0) log("refresh_requested");
        texture.forceFrame();
    }

    /** Called on the texture thread before stopListening, or posted by dispose. */
    public void stop() {
        refresh.stop();
        if (running) log("stopped");
        running = false;
    }

    public void dispose() { handler.post(this::stop); }

    private void log(String event) {
        Log.i(TAG, "event=" + event + " elapsed_ms=" + (System.nanoTime() - started) / 1_000_000
                + " captured_frames=" + captured + " source_frames=" + sources
                + " forwarded_frames=" + forwarded + " refresh_requests=" + requests);
    }
}
