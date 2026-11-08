# Issue 675: Windows welcome author acceptance

Product source: master `8306413a84c224a712509d7a059916c95b00bd3c`; fix PR #677 is already merged. The integration test has an optional QA-only screenshot hook; it does not change product code.

On Windows 11, the full Flutter debug application was built and tested against a disposable localhost API and PostgreSQL stack with synthetic accounts. The existing integration test registered a new peer, removed its profile from the local member cache and opened actual channel history. Result: `WELCOME_FULL_WORKSPACE_PASS uncached_author=true`, exit 0. The screenshot was inspected at its original 1266 x 683 resolution: the welcome row visibly shows the synthetic peer's name rather than the fallback; the row is legible and untruncated. Screenshot SHA-256: `ed3ce6f3f5b191f18b7b424ab09afe64a43dcc4f40410a04ac37e6bdb6541bc0`. Synthetic screenshots are local QA artifacts, not repository content.

The focused Flutter tests `system_welcome_author_test.dart`, `system_welcome_lookup_test.dart`, and `system_welcome_session_test.dart` passed (3 tests), covering lookup, unavailable profiles and the old-session response fence. The existing Firebase SDK and Velopack SDK were reused for this local debug build.

Scope: Windows debug integration and focused Flutter tests, not a new signed installer or deployment. No production server was modified.
