# PR 696: Android gate and CI investigation

On 2026-11-09 the owned local-feature gate ran on a dedicated Android 35
emulator, source `a0982fd7e1b8423ecd310e82b34b26ea40e75ffb`, tracked diff
SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`,
base `c96af5782b34d968fbc43de831cf816840316de5`. Selected features were auth,
connection_status, screen, shell and voice. An isolated API, PostgreSQL and
LiveKit stack and a localhost-only VM-service relay were used.

Flutter unit PASS: 1,822 passed, 3 skipped; selected component tests PASS:
591 passed; Android runtime PASS: authentication, workspace, profile/audio/
admin panels and logout. The runtime does not exercise the changed voice
grid, calling, audio or screen-reader behavior. Overall report remains
REVIEW_REQUIRED and visual_review NOT_RUN. Report SHA-256:
`074d96a6f41322a46f7448abf54640b780fc67c56263a9861fc81c1b304f860c`.
The focused 320 x 480 voice capture matches the individually viewed image
`f53541c0924c47348cef457acdbb41c7471ab59cd3ceff7959d3f481d1c92396`;
other captures in this run have not been fully reviewed. The dedicated
emulator and relay were stopped, and its owned ADB forward removed.

The first attempt omitted required feature selections and stopped at the
coverage check; a complete run on an earlier commit and the run above used
all required selections. CI run 42565951966 on `a0982fd7e` failed: JDK,
Gradle and the Windows updater SDK downloads returned HTTP 504; contracts
also reported the feature registry digest mismatch. A subsequent commit added
a source-only digest overlay; 18 LiveKit verifier tests and the parity
validator pass locally. That later commit is not covered by this native run.
CI and exact-current-head acceptance remain pending; no deploy or physical
media acceptance is claimed.
