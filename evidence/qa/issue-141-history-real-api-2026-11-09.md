# Issue 141: edit retention with a real API

Product source `8306413a84c224a712509d7a059916c95b00bd3c`, Windows 11 with Chromium in WSL, real Vue conversation component/store, and a disposable loopback-only Go API/PostgreSQL 17.6 stack. The proxy translated fixture Origin to the owned TLS endpoint; this is not an Origin-policy acceptance. No production service was modified.

The disposable fixture contained 1,000 synthetic messages, 500 with replies. The browser loaded real protected API pages and maintained a 500-message cache. In three independent runs, editing the latest message, loading an older page, and returning through three newer pages preserved the exact unsaved text; the target was demonstrably evicted and subsequently restored. No PATCH or DELETE was made. A 450-message no-eviction control also passed. The restored editor screenshot was inspected at 1440 x 1000: draft and buttons were visible. Its local artifact SHA-256 is `aa1d2b4290ed0d6c8e9a2fd5fc3ef277883854edc4cf3e694e729413e11d91e5`.

The project's four focused browser files passed 28 tests covering edit retention, account isolation and conflict states. Separate focused captures at 1440 and 393 were inspected; these fixtures mock API traffic and do not replace the actual-API test.

The local runner `.out/qa141-real.mjs` has SHA-256 `c48e3e7a21394603e20372d4f87cbe83b8b4136553d01dd908c73dcc62fbda18`; the disposable seed script `.out/qa141-seed.py` has SHA-256 `8c7b2fc686fedc84096dbc0a64384486f41de579481a03229bc193a2091cc1ff`. Both use local fixture identities and require a newly owned stack and credentials to reproduce; raw synthetic data, credentials and screenshots are not committed. The stack's normal cleanup removed its containers and database.

Result: PASS_SCOPED for the historical edit-loss counterexample, not full issue acceptance. The 50/500/5,000/10,000 history and reply-density matrix, before/after measurements, protected-image and full application checks, and the canonical preview-refresh gate remain separate. Issue #141 remains open.

## Built Web and 10,000 messages

The retained `issue141-real-stack-2026-11-07/current-10000` runner was repeated at this source in a fresh owned stack. The first run stopped at `initial_history`: its assertion expected the latest row visible immediately, while the reviewed screenshot showed the top of the loaded page. This is a failed test setup, not evidence of the edit behavior. A second run added an explicit scroll to the latest loaded row before that assertion and adjusted the local screenshot path; it passed at 1440 x 900: 10 older and 3 newer API pages, the same editor and selection retained through eviction and restoration. The source-resolution screenshot shows the draft and controls; a channel-loading label is still visible. At the loaded-500 checkpoint it reported 823 DOM nodes and 31,435,484 bytes JS heap, with no observed long tasks. One sample is not an INP, memory maximum or performance guarantee. No reply-density coverage is claimed by this 10,000-row seed. The owned stack cleaned up.

The original historical local-features command was also repeated unchanged. It failed selection before runtime: eight additional feature groups and unclassified changed paths were reported relative to the historical base. This is not a screen-preview runtime result, and it does not replace the required canonical gate.

The adjusted 10,000-message runner also passed at 393 x 852 CSS pixels with mobile browser emulation and device scale 3. The inspected 1179 x 2556 screenshot shows the restored draft and controls. At loaded-500 the run reported 744 DOM nodes and 36,334,796 bytes JS heap, with no observed long tasks. This is browser emulation, not an Android-native or physical-device result; the owned stack cleaned up.
