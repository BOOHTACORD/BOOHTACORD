package com.cloudwebrtc.webrtc.screen.refresh;

/** One callback on the capture thread; never owns or retains a media buffer. */
final class StationaryFrameRefresh {
    interface Scheduler {
        void postDelayed(Runnable task, long delayMillis);
        void remove(Runnable task);
    }
    interface Clock { long millis(); }
    private final Scheduler scheduler;
    private final Clock clock;
    private final Runnable requestFrame;
    private boolean running, visible, hasFrame;
    private long lastSourceFrameAt;
    private Runnable scheduled;

    StationaryFrameRefresh(Scheduler scheduler, Clock clock, Runnable requestFrame) {
        this.scheduler = scheduler;
        this.clock = clock;
        this.requestFrame = requestFrame;
    }

    void start() {
        stop();
        running = true;
        visible = true;
    }

    void frameArrived() {
        if (!running || !visible) return;
        hasFrame = true;
        lastSourceFrameAt = clock.millis();
        arm();
    }

    void setVisible(boolean value) {
        if (visible == value) return;
        visible = value;
        hasFrame = false;
        cancel();
    }

    void stop() {
        running = false;
        hasFrame = false;
        cancel();
    }

    private void cancel() {
        if (scheduled != null) scheduler.remove(scheduled);
        scheduled = null;
    }

    private void arm() {
        if (scheduled != null || !running || !visible || !hasFrame) return;
        scheduled = new Runnable() {
            @Override public void run() {
                if (scheduled != this) return; // Includes a stopped/restarted generation.
                scheduled = null;
                if (!running || !visible || !hasFrame) return;
                if (clock.millis() - lastSourceFrameAt >= 1000) requestFrame.run();
                arm();
            }
        };
        scheduler.postDelayed(scheduled, 1000);
    }
}
