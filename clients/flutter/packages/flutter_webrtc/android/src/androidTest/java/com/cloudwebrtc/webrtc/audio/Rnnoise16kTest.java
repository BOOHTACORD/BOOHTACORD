package com.cloudwebrtc.webrtc.audio;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Map;
import org.junit.Test;
import static org.junit.Assert.*;

public final class Rnnoise16kTest {
    @Test public void processesAndroidVoiceFramesAt16k() {
        RnnoiseCaptureAdapter adapter = new RnnoiseCaptureAdapter(false);
        try {
            assertTrue(adapter.setEngine("rnnoise"));
            adapter.initialize(16000, 1);
            ByteBuffer pcm = ByteBuffer.allocateDirect(160 * 4).order(ByteOrder.nativeOrder());
            for (int i = 0; i < 160; i++) pcm.putFloat(i * 4, (float) (5000 * Math.sin(i * .17)));
            adapter.process(1, 160, pcm);
            Map<String, Object> state = adapter.state();
            assertEquals("rnnoise", state.get("effectiveEngine"));
            assertEquals("", state.get("failureReason"));
            assertEquals(1L, state.get("processedFrames"));
        } finally {
            adapter.close();
        }
    }
}
