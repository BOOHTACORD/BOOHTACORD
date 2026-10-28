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
    private enum Visibility { UNKNOWN, VISIBLE, HIDDEN }
    private boolean running, hasFrame;
    private Visibility visibility;
    private long lastSourceFrameAt;
    private Runnable scheduled;

    StationaryFrameRefresh(Scheduler scheduler, Clock clock, Runnable requestFrame) {
        this.scheduler = scheduler;
        this.clock = clock;
        this.requestFrame = requestFrame;
    }

    void start() { start(false); }

    void start(boolean awaitVisibility) {
        stop();
        running = true;
        visibility = awaitVisibility ? Visibility.UNKNOWN : Visibility.VISIBLE;
    }

    void frameArrived() {
        if (!running || visibility == Visibility.HIDDEN) return;
        hasFrame = true;
        lastSourceFrameAt = clock.millis();
        arm();
    }

    void setVisible(boolean value) {
        Visibility next = value ? Visibility.VISIBLE : Visibility.HIDDEN;
        if (visibility == next) return;
        if (visibility != Visibility.UNKNOWN || !value) hasFrame = false;
        visibility = next;
        if (value) arm(); else cancel();
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
        if (scheduled != null || !canRepeat()) return;
        scheduled = new Runnable() {
            @Override public void run() {
                if (scheduled != this) return; // Includes a stopped/restarted generation.
                scheduled = null;
                if (!canRepeat()) return;
                if (clock.millis() - lastSourceFrameAt >= 1000) requestFrame.run();
                arm();
            }
        };
        scheduler.postDelayed(scheduled, 1000);
    }

    boolean canRepeat() { return running && visibility == Visibility.VISIBLE && hasFrame; }
}
