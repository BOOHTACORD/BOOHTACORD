package com.cloudwebrtc.webrtc;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.AudioPlaybackCaptureConfiguration;
import android.media.projection.MediaProjection;
import android.os.Build;
import android.util.Log;

import org.webrtc.AudioSource;

/** Captures eligible app playback and pushes PCM into a WebRTC AudioSource. */
final class ScreenAudioCapture {
    private static final String TAG = "ScreenAudioCapture";
    private static final int SAMPLE_RATE = 48000;
    private static final int CHANNELS = 2;
    private static final int FRAMES_PER_READ = SAMPLE_RATE / 100;

    static {
        System.loadLibrary("boohta_rnnoise_android");
    }

    private final Context context;
    private final long nativeSource;
    private final AudioSource audioSource;
    private volatile boolean capturing;
    private volatile boolean disposed;
    private AudioRecord audioRecord;
    private Thread captureThread;

    ScreenAudioCapture(Context context) {
        this.context = context.getApplicationContext();
        this.nativeSource = nativeCreateSource();
        if (nativeSource == 0) throw new IllegalStateException("Screen audio source is unavailable");
        this.audioSource = new AudioSource(nativeSource);
    }

    AudioSource audioSource() {
        return audioSource;
    }

    boolean start(MediaProjection projection) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || projection == null || disposed ||
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false;
        }
        try {
            AudioPlaybackCaptureConfiguration configuration =
                    new AudioPlaybackCaptureConfiguration.Builder(projection)
                            .addMatchingUsage(android.media.AudioAttributes.USAGE_MEDIA)
                            .addMatchingUsage(android.media.AudioAttributes.USAGE_GAME)
                            .addMatchingUsage(android.media.AudioAttributes.USAGE_UNKNOWN)
                            .build();
            AudioFormat format = new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                    .build();
            int minimum = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT);
            if (minimum <= 0) return false;
            audioRecord = new AudioRecord.Builder()
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(Math.max(minimum, FRAMES_PER_READ * CHANNELS * 2 * 4))
                    .setAudioPlaybackCaptureConfig(configuration)
                    .build();
            if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                releaseAudioRecord();
                return false;
            }
            audioRecord.startRecording();
            if (audioRecord.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) {
                releaseAudioRecord();
                return false;
            }
            capturing = true;
            captureThread = new Thread(this::readLoop, "WebRTC-screen-audio");
            captureThread.setDaemon(true);
            captureThread.start();
            return true;
        } catch (SecurityException | IllegalArgumentException | IllegalStateException error) {
            Log.i(TAG, "Playback capture unavailable on this device");
            releaseAudioRecord();
            return false;
        }
    }

    boolean isCapturing() {
        return capturing;
    }

    void stop() {
        capturing = false;
        AudioRecord record = audioRecord;
        if (record != null) {
            try {
                if (record.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) record.stop();
            } catch (IllegalStateException ignored) { }
        }
        Thread thread = captureThread;
        if (thread != null && thread != Thread.currentThread()) {
            try {
                thread.join(500);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
            }
        }
        captureThread = null;
        releaseAudioRecord();
        nativeStopSource(nativeSource);
    }

    void dispose() {
        if (disposed) return;
        disposed = true;
        stop();
        audioSource.dispose();
    }

    private void readLoop() {
        short[] pcm = new short[FRAMES_PER_READ * CHANNELS];
        while (capturing && !disposed) {
            AudioRecord record = audioRecord;
            if (record == null) break;
            int samplesRead;
            try {
                samplesRead = record.read(pcm, 0, pcm.length, AudioRecord.READ_BLOCKING);
            } catch (IllegalStateException error) {
                break;
            }
            if (samplesRead < 0) break;
            if (samplesRead > 0) {
                int completeSamples = samplesRead - (samplesRead % CHANNELS);
                if (completeSamples > 0) {
                    nativeCaptureFrame(nativeSource, pcm, completeSamples, SAMPLE_RATE, CHANNELS);
                }
            }
        }
        capturing = false;
    }

    private void releaseAudioRecord() {
        AudioRecord record = audioRecord;
        audioRecord = null;
        if (record != null) {
            try {
                record.release();
            } catch (IllegalStateException ignored) { }
        }
    }

    private static native long nativeCreateSource();
    private static native void nativeCaptureFrame(
            long source, short[] samples, int sampleCount, int sampleRate, int channels);
    private static native void nativeStopSource(long source);
}
