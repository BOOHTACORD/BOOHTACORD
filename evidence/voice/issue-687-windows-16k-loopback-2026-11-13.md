# Issue 687: Windows 16 kHz capture and local loopback

At parent source `dca80539fadbed6d708ffc52ce2f2fcb93b6702f` with the changes
in this packet, an unsigned research Flutter diagnostic used the actual Windows
WebRTC plugin, the local physical microphone and two local WebRTC peers with no
ICE servers. It stored aggregate state and RTP counts only; no PCM or SDP was
recorded. Host: Windows 10.0.26300, Intel i7-12700. The installed client and
server were not modified.

Before these changes, native WebRTC presented mono 16 kHz capture. The model
only accepted 48 kHz: over the eight-second test it processed zero frames and
reported 795 unsupported-format fallbacks. After rate conversion alone, another
run reported repeated processor failure as capture restarted model preparation.
The processing callback now outputs silence while the current model generation
is preparing and accepts 160-sample/16 kHz blocks via fixed-buffer 16в†”48 kHz
FIR conversion. The two 127-tap filters have a nominal combined delay of
2.625 ms; this is not measured end-to-end processing latency.

The checked-in diagnostic `tools/audio/windows_client_probe` was then built
and run with the experimental native flag and locally verified research model.
One run observed one audio track, 752 processed frames at 16 kHz, zero
fallbacks, and 403 inbound RTP packets (15,373 bytes). The engine reported
`deepfilter` effective. The output and executables had these SHA-256 values:

- Probe executable: `ef74895de1aa784730dae8d117dd5e7c2e2551df38f4f3531312beec0b39fb42`.
- WebRTC plugin: `93c26eb8ff144cb9d5bb70f59a0dc83bda506aa9ac3ca02d1c58c85defefcc79`.
- Aggregate result: `d081990be4993cfec2cbe66175f96ec9104844175f3a17ed23a45739b54c3670`.

The MSVC native suite passed 21/21, including tests for 16 kHz preparation, 6 kHz passband,
10 kHz anti-alias rejection, full-scale limits and no heap allocation in the
resampler. One real-device 8-second
loopback does not establish audibility, speech quality, 30-minute stability,
actual LiveKit or installed signed-release behavior. Those gates remain
NOT_RUN; it does not satisfy issue closure.
A normal Windows application build with the experimental native flag OFF also
completed after the diagnostic; it was neither installed nor deployed.
