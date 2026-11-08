# Issue 141: edit retention with a real API

Product source `8306413a84c224a712509d7a059916c95b00bd3c`, Windows 11 with Chromium in WSL, real Vue conversation component/store, and a disposable loopback-only Go API/PostgreSQL 17.6 stack. The proxy translated fixture Origin to the owned TLS endpoint; this is not an Origin-policy acceptance. No production service was modified.

The disposable fixture contained 1,000 synthetic messages, 500 with replies. The browser loaded real protected API pages and maintained a 500-message cache. In three independent runs, editing the latest message, loading an older page, and returning through three newer pages preserved the exact unsaved text; the target was demonstrably evicted and subsequently restored. No PATCH or DELETE was made. A 450-message no-eviction control also passed. The restored editor screenshot was inspected at 1440 x 1000: draft and buttons were visible. Its local artifact SHA-256 is `aa1d2b4290ed0d6c8e9a2fd5fc3ef277883854edc4cf3e694e729413e11d91e5`.

The project's four focused browser files passed 28 tests covering edit retention, account isolation and conflict states. Separate focused captures at 1440 and 393 were inspected; these fixtures mock API traffic and do not replace the actual-API test.

The local runner `.out/qa141-real.mjs` has SHA-256 `c48e3e7a21394603e20372d4f87cbe83b8b4136553d01dd908c73dcc62fbda18`; the disposable seed script `.out/qa141-seed.py` has SHA-256 `8c7b2fc686fedc84096dbc0a64384486f41de579481a03229bc193a2091cc1ff`. Both use local fixture identities and require a newly owned stack and credentials to reproduce; raw synthetic data, credentials and screenshots are not committed. The stack's normal cleanup removed its containers and database.

Result: PASS_SCOPED for the historical edit-loss counterexample, not full issue acceptance. The 50/500/5,000/10,000 history and reply-density matrix, before/after measurements, protected-image and full application checks, and the canonical preview-refresh gate remain separate. Issue #141 remains open.
