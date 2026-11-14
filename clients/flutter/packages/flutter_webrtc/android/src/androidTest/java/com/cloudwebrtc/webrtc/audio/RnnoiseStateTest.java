package com.cloudwebrtc.webrtc.audio;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Map;
import org.junit.Test;
import static org.junit.Assert.*;

/** Uses the packaged JNI library, with synthetic PCM and no microphone permission. */
public final class RnnoiseStateTest {
    @Test public void pendingActiveAndResetStatesCrossTheRealJniBoundary() {
        RnnoiseCaptureAdapter adapter = new RnnoiseCaptureAdapter(false);
        try {
            assertTrue(adapter.setEngine("rnnoise"));
            Map<String, Object> pending = adapter.state();
            assertEquals(true, pending.get("supported"));
            assertEquals("unknown", pending.get("effectiveEngine"));
            assertEquals("awaiting-audio", pending.get("failureReason"));
            assertEquals(0L, pending.get("processedFrames"));
            adapter.initialize(48000, 1);
            ByteBuffer pcm = ByteBuffer.allocateDirect(480 * 4).order(ByteOrder.nativeOrder());
            for (int i = 0; i < 480; i++) pcm.putFloat(i * 4, (float) (5000 * Math.sin(i * .17)));
            adapter.process(1, 480, pcm);
            Map<String, Object> active = adapter.state();
            assertEquals("rnnoise", active.get("effectiveEngine"));
            assertEquals("", active.get("failureReason"));
            assertEquals(1L, active.get("processedFrames"));
            adapter.resetState();
            assertEquals("unknown", adapter.state().get("effectiveEngine"));
            assertEquals("awaiting-audio", adapter.state().get("failureReason"));
            adapter.process(1, 480, pcm);
            assertEquals("rnnoise", adapter.state().get("effectiveEngine"));
            assertFalse(adapter.setEngine("deepfilter"));
            assertTrue(adapter.setEngine("browser"));
            assertEquals("browser", adapter.state().get("effectiveEngine"));
        } finally {
            adapter.close();
        }
    }
}
