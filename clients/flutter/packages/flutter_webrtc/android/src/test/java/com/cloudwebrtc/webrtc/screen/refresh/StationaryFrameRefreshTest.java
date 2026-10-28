package com.cloudwebrtc.webrtc.screen.refresh;

import static org.junit.Assert.*;
import org.junit.Test;

public class StationaryFrameRefreshTest {
    private static class Harness implements StationaryFrameRefresh.Scheduler {
        long now;
        int requests;
        Runnable pending;
        final StationaryFrameRefresh refresh = new StationaryFrameRefresh(
                this, () -> now, () -> requests++);
        public void postDelayed(Runnable task, long delay) {
            assertNull("Only one refresh callback may be queued", pending);
            assertEquals(1000, delay);
            pending = task;
        }
        public void remove(Runnable task) { if (pending == task) pending = null; }
        void tick() { now += 1000; Runnable task = pending; pending = null; task.run(); }
    }

    @Test public void stationaryFrameIsAvailableAfterPublisherBecomesReady() {
        Harness h = new Harness();
        h.refresh.start(); h.refresh.frameArrived();
        h.tick(); h.tick();
        assertEquals(2, h.requests);
        assertNotNull(h.pending); // Also serves a subscriber joining later.
    }

    @Test public void neverSynthesizesAnUninitializedTexture() {
        Harness h = new Harness(); h.refresh.start();
        assertNull(h.pending); assertEquals(0, h.requests);
    }

    @Test public void movingSourceDoesNotRequestExtraFrames() {
        Harness h = new Harness(); h.refresh.start(); h.refresh.frameArrived();
        h.now = 900; h.refresh.frameArrived(); h.tick();
        assertEquals(1, h.requests);
        h.now = 2000; h.refresh.frameArrived(); h.now = 2500;
        Runnable task = h.pending; h.pending = null; task.run();
        assertEquals(1, h.requests);
    }

    @Test public void hidingCancelsAndVisibilityAloneCannotReplayOldContent() {
        Harness h = new Harness(); h.refresh.start(); h.refresh.frameArrived();
        Runnable stale = h.pending;
        h.refresh.setVisible(false); assertNull(h.pending);
        stale.run(); assertEquals(0, h.requests); assertNull(h.pending);
        h.refresh.frameArrived(); h.refresh.setVisible(true);
        assertNull(h.pending);
        h.refresh.frameArrived(); h.tick(); assertEquals(1, h.requests);
    }

    @Test public void stopCancelsPendingAndRestartRequiresNewFrame() {
        Harness h = new Harness(); h.refresh.start(); h.refresh.frameArrived();
        Runnable stale = h.pending; h.refresh.stop();
        stale.run(); assertNull(h.pending); assertEquals(0, h.requests);
        h.refresh.start(); assertNull(h.pending);
        h.refresh.frameArrived(); h.tick(); assertEquals(1, h.requests);
    }

    @Test public void oldGenerationCannotRefreshOrReplaceNewGenerationTimer() {
        Harness h = new Harness(); h.refresh.start(); h.refresh.frameArrived();
        Runnable stale = h.pending;
        h.refresh.stop(); h.refresh.start(); h.refresh.frameArrived();
        Runnable current = h.pending;
        stale.run(); assertSame(current, h.pending); assertEquals(0, h.requests);
        h.tick(); assertEquals(1, h.requests);
    }

    @Test public void firstVisibilityConfirmationCanFollowTheFirstSourceFrame() {
        Harness h = new Harness(); h.refresh.start(true); h.refresh.frameArrived();
        assertNull(h.pending); // Do not repeat before visibility is confirmed.
        h.refresh.setVisible(true); h.tick(); assertEquals(1, h.requests);
    }

    @Test public void firstHiddenNotificationInvalidatesTheUnconfirmedImage() {
        Harness h = new Harness(); h.refresh.start(true); h.refresh.frameArrived();
        h.refresh.setVisible(false); h.refresh.setVisible(true);
        assertNull(h.pending);
        h.refresh.frameArrived(); h.tick(); assertEquals(1, h.requests);
    }
}
