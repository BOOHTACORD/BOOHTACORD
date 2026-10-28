package com.cloudwebrtc.webrtc.screen.refresh;

import static org.junit.Assert.assertEquals;
import org.junit.Test;

public class FrameTimestampTest {
    @Test public void repeatingATextureAdvancesTimestampByElapsedMonotonicTime() {
        FrameTimestamp clock = new FrameTimestamp();
        assertEquals(100, clock.next(100, 1000));
        assertEquals(1100, clock.next(100, 2000));
        assertEquals(2100, clock.next(100, 3000));
    }

    @Test public void sourceClockIsPreservedAndResumesWithoutGoingBackwards() {
        FrameTimestamp clock = new FrameTimestamp();
        assertEquals(100, clock.next(100, 1000));
        assertEquals(1100, clock.next(100, 2000));
        assertEquals(1200, clock.next(1050, 2100));
        assertEquals(2000, clock.next(2000, 2200));
        clock.reset();
        assertEquals(50, clock.next(50, 3000));
    }
}
