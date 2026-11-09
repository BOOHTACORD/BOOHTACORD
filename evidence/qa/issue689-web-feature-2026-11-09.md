# Issue 689: Web feature and screen-baseline checks

- The Web feature run `.out/local-features/20261109-105609/` used dirty source
  at HEAD `72928320d` with matching start/end worktree fingerprint. Web unit
  tests passed: 531 files, 1820 tests. Production-mode Web build passed with a
  loopback test origin. Browser configurations passed except one skipped test
  in `web-screen_profile`; the old reporter incorrectly marked that stage PASS.
- Both real-stack browser lifecycle scenarios passed on 1440 and 393 CSS pixel
  widths, using isolated PostgreSQL and LiveKit. The report remains
  `REVIEW_REQUIRED`; it lists 873 screenshots. Only four were inspected here at
  source resolution: the empty voice prejoin and application-socket-failure
  screenshots at each width. Join controls and the empty state were visible;
  the failure screenshots showed voice still marked connected. The two widths
  were separate runs, so their participant counts are not a cross-client proof.
- The skipped `minimal publisher/viewer produces numeric baseline evidence`
  test was run separately on a dedicated loopback LiveKit 1.13.7 fixture with
  synthetic video and short-lived fixture credentials. One test passed in 3.6
  minutes; the owned container was removed and source fingerprint matched. The
  test's numeric attachment was not retained by its configured reporter. This
  does not establish physical screen-capture or capacity results.
- The local feature reporter was subsequently corrected to mark skipped or
  missing Web unit/Playwright summaries `BLOCKED`; reclassifying this earlier
  run yields 27 passing test groups and one blocked screen-profile group.
  The earlier report cannot by itself close the gate, and the current reporter
  needs a fresh real-stack run. Remaining screenshots, full native/media,
  immutable-build and release acceptance stay NOT_RUN.
