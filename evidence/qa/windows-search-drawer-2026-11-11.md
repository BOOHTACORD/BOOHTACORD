# Windows acceptance navigation, 2026-11-11

- CI run 43087965119 failed at `search_open/control_missing`. Its retained
  synthetic screenshot showed the text channel with the navigation drawer
  closed. The exact cause of the closure is not established.
- The acceptance driver now reopens the drawer at most three times if the
  search launcher is not hit-testable. It still requires the launcher, actual
  channel selection, listener connection and the original GUI/SFU assertions.
- A focused test failed on the prior driver when the drawer closed once, then
  passed with the change. A repeatedly closing drawer still fails after three
  attempts. Thirteen focused and neighboring Flutter tests passed locally.
- Hosted Windows GUI/SFU acceptance on the changed driver: NOT_RUN until CI
  completes. This is a QA-driver change and does not establish an Android ICE fix.
