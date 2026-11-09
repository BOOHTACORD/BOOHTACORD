# PR 695: voice component visual review

2026-11-09. Initially reviewed the 27 component captures listed below in
groups from the Android local-feature gate on source
`c96af5782b34d968fbc43de831cf816840316de5`. The gate report SHA-256 is
`fc380a4f7b66fab9e9b335a22da97dcd24b1b3d289e6d0dd70da01933aea6ff5`.
These are fixture captures, not interactive or media acceptance.

The grouped viewer output was truncated, so the initial claim that several
voice controls were outside the visible image was incorrect. Individually
reopened at original resolution, the full-layout scale-2 captures at widths
320, 390, 768, 1024 and 1440 show the voice control row. An instrumented copy
of the native widget scenario with the original fonts found the leave button
hit-testable without scrolling at 320 x 480 and 1024 x 480. Rectangles were
respectively (260, 424)-(308, 472) and (223, 359)-(265, 401). The repeated
1024 capture matched the gate image SHA-256 byte for byte. This checks hit
testing, not invocation or device accessibility. At 320 x 480 and text scale
2 with five or ten participants, the initial grouped captures show awkward
wrapping and a tiny preview label; those captures need individual review.

Reviewed filenames:

- `flutter-connection-status-desktop-320x380.png`
- `flutter-connection-status-mobile-320x380.png`
- `flutter-participant-cards-stream-and-voice.png`
- `flutter-sidebar-after-voice-leave-300x640.png`
- `guild-member-voice-channel.png`
- `parity-voice-1-1440x480-scale2.png`
- `parity-voice-1-320x480-scale2.png`
- `parity-voice-1-768x480-scale2.png`
- `parity-voice-10-1440x480-scale2.png`
- `parity-voice-10-320x480-scale2.png`
- `parity-voice-10-768x480-scale2.png`
- `parity-voice-1024x480-scale1.png`
- `parity-voice-1024x480-scale2.png`
- `parity-voice-1440x480-scale1.png`
- `parity-voice-1440x480-scale2.png`
- `parity-voice-320x480-scale1.png`
- `parity-voice-320x480-scale2.png`
- `parity-voice-390x480-scale1.png`
- `parity-voice-390x480-scale2.png`
- `parity-voice-5-1440x480-scale2.png`
- `parity-voice-5-320x480-scale2.png`
- `parity-voice-5-768x480-scale2.png`
- `parity-voice-768x480-scale1.png`
- `parity-voice-768x480-scale2.png`
- `voice-viewer-participants-fullscreen-open.png`
- `voice-viewer-participants-room-open.png`
- `voice-viewer-participants-room.png`

Only the five full-layout component images explicitly listed by width above
have been individually rechecked after discovering the truncation. Together
with the previously individually reviewed 14 native captures, at least 19 of
the 188 reported captures have been checked this way. The other 169 require
individual review; the original report remains REVIEW_REQUIRED and its
visual review remains NOT_RUN. No screenshot baseline was approved.
