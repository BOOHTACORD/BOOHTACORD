package com.cloudwebrtc.webrtc.screen.refresh;

/** forceFrame repeats the SurfaceTexture timestamp; encoders need advancing time. */
final class FrameTimestamp {
    private long output = Long.MIN_VALUE;
    private long wall;

    long next(long source, long now) {
        output = output == Long.MIN_VALUE || source > output
                ? source : output + Math.max(1, now - wall);
        wall = now;
        return output;
    }

    void reset() { output = Long.MIN_VALUE; }
}
