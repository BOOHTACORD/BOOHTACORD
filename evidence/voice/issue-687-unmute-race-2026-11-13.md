# Issue 687: RNNoise Web mute intent race

At source `42be2bbab80c27cceaae1d00d54b884107a9c715`, unit tests exercise
mute arriving before an unmute acknowledgement, a delayed acknowledgement for
an earlier request, and a processor failure while unmute is pending. The
first two cases failed before the change: the cancelled request remained
pending and could time out. The worklet now echoes the unmute intent; the
processor ignores old acknowledgements and rejects a pending unmute on error.
The adapter still controls final track enablement after checking user intent.

On Windows, 67 Web noise-suppression and microphone-processing unit tests and
the production Web build passed. At preceding source `786f3173c`, Chromium
153 and Firefox 155 each passed the synthetic 20-cycle mute/unmute race and
direct WebRTC peer/mute test with the local experimental v0.2 model enabled.
The tests use generated audio and are not physical microphone, end-to-end
LiveKit, speech quality, 30-minute stability or production-release acceptance.
The v0.2 model files were removed from the public directory after testing.

The full Web local-features run at `786f3173c` is separate and has not passed
at the time of this record. No server deployment was performed.
