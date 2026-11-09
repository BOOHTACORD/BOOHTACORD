# PR 695: voice component visual review

2026-11-09. Reviewed at original resolution the 27 component captures listed
below from the Android local-feature gate on source
`c96af5782b34d968fbc43de831cf816840316de5`. The gate report SHA-256 is
`fc380a4f7b66fab9e9b335a22da97dcd24b1b3d289e6d0dd70da01933aea6ff5`.
These are fixture captures, not interactive or media acceptance.

The connection status captures show the expected separate chat, voice and
roster states. Viewer participant menus and ordinary-scale voice controls are
visible in the corresponding captures. At 320 x 480 and text scale 2 with
five or ten participants, text in narrow voice cards wraps awkwardly and the
stream preview label is extremely small. In several full-layout captures at
480 pixels height and scale 2, voice controls are outside the visible image;
whether they can be reached by scrolling or other interaction was not tested.
These observations require interactive follow-up and are not an acceptance
of accessibility or a diagnosis of their cause.

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

Together with the previously reviewed 14 native captures, 41 of the 188
reported captures have been inspected. The other 147 component captures
remain unreviewed; the original report remains REVIEW_REQUIRED and its visual
review remains NOT_RUN. No screenshot baseline was approved.
