# PR 692: Windows acceptance navigation

The exact-merge CI run 42882997953 failed its Windows GUI/SFU scenario at
`voice_open: control_missing`. Its retained synthetic failure screenshot shows
the message-search panel, rather than the channels-and-people view. This does
not establish why the panel returned to message search.

The QA driver now retries the visible mode switch at most three times; it still
requires the requested channel, listener admission, real LiveKit connection,
and all original Windows GUI/SFU assertions. A regression test reproduces one
panel reset and checks that three consecutive resets do not report success.
Before the change the one-reset test failed at `control_missing`. Afterwards,
both new cases and nine neighboring journey tests passed locally on Windows.

Full native Windows GUI/SFU acceptance of the changed driver: PENDING CI.
The physical Android WebRTC incident is outside this test's coverage.
