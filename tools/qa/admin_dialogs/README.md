# Admin and dialog runtime QA (#295, #298)

This runner uses the production Vue app or `BoohtacordApp`, a disposable Go/PostgreSQL/Tempo deployment, and two real LiveKit listeners. Every API mutation belongs to its own disposable guild. Fixed MEMBER and ADMINISTRATOR roles are preserved; no custom-role or invitation feature is introduced.

```
python3 -m unittest discover -s tools/qa/admin_dialogs -t . -q
clients/web/node_modules/.bin/playwright test -c tools/qa/admin_dialogs/playwright.config.mjs
QA_WIDTHS=320,393,1440 python3 -m tools.qa.admin_dialogs.run
python3 -m tools.qa.admin_dialogs.run_native --platform android
python3 -m tools.qa.admin_dialogs.run_native --platform ios
```

Use the coordinated Flutter SDK build lease before any native invocation. The Android runner accepts only emulator-5554 / BOOHTACORD_QA_API35. The iOS runner accepts only its separately assigned BOOHTACORD QA295 simulator. Neither runner selects another device after a preflight failure.

Native service ports are HTTPS 4950, API 4951, Tempo 4952, SFU 4990 / TCP 4991 / UDP 4995. The independent Web stack uses HTTPS 4960, API 4961, Tempo 4962, SFU 4996 / TCP 4997 / UDP 4999. Only these two registered port sets are accepted. The focused browser fixture uses 4957. Services have a unique `qa295298-` owner label. Cleanup attempts every acquired resource and cannot remove resources with a different label. Android reverse ports are tracked individually, including partial installation failures.

Web artifacts are copied into an owned temporary directory before serving; their exact manifest is checked against the shared artifact to reject concurrent rebuilds. Native app `lib` and integration entry hashes must match the repository before compilation. The private native copy preserves production directories called `build` while excluding root compiled artifacts.

Each attempt archives prior files before preflight and writes RUNNING, then FAIL on errors. A reused previous PASS cannot survive a setup failure. Captures and sanitized receipts live under ignored `.out/qa295298-20261012`; generated media is never staged. Credentials and raw native-driver output are private temporary files. The private compiled native copy must be removed after the coordinated Android/iOS runs, since its compiled app contains disposable QA defines.

The admin scenario exercises all seven sections while retaining the selected conversation, draft and voice lease, then returning and reopening. Dialog scenarios cover validation, cancellation, pending duplicate protection, real success, destructive target confirmation, Escape/route Back, and role permission saving. Web additionally uses a stopped owned API for a real failure/retry, a real permission revision conflict, text archive, inactive voice close, and topology revision invalidation of a pending destructive confirmation. A held successful HTTP response measures pending presentation; it never fabricates a successful backend response.

Browser keyboard and integration route dispatch are controlled runtime checks. They do not prove physical touch, hardware Back, spoken readers, native OS picker operation or audible media. Missing physical and spoken-reader acceptance remains NOT_RUN and keeps both issues open.

The focused backend regression `TestMemberPolicyRealPostgresCommitsRevisionAndAuditAtomically` uses the existing isolated PostgreSQL fixture (`VOICE_PLATFORM_TEST_DATABASE_URL`, loopback only) and full migrations. Run `go test ./internal/authorization/role_policy/postgres -count=1` from `backend` with an owned test database. It checks committed policy and audit revision plus stale revision rejection. The captured PostgreSQL RED SQLSTATE 42P18 is independent of the browser/native UI.

Focused Flutter validation includes the six create-error readability/semantic-association cases at320/360/393 logical pixels and1×/2× text, alongside existing admin and confirmation tests. The stock errorText supplies the field error hint and platform live-region; no custom error widget replaces it. Scoped analyzer results retain five pre-existing style infos and do not claim a full analyzer PASS.

The focused browser matrix also checks destructive target text width and pointer-reachable actions at normal/enlarged text while retaining the287px desktop baseline. Actual320 normal/enlarged confirmation checks run with the real API/SFU. Public evidence distinguishes measured historical393/1440 artifacts from the latest confirmation repeat; it does not retag artifact hashes.
