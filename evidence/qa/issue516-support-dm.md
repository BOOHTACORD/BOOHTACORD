# #516 — server-assigned support through ordinary pair DM

Source: `codex/issue516-support-dm`, based on `a77da2cc86eb09110039da2e970549d4ea286bd2`; owner specification updated 22 October 2026. Leaf SP-001 depends on T-010/T-041/T-044. All accounts/content are synthetic. Production configuration was not changed.

## Automated results

| Check | Outcome / evidence |
| --- | --- |
| Go focused + actual disposable PostgreSQL | PASS: support resolution/configuration, migration 0055, A/S and B/S messages/replies/history, ClientMessageID dedup, attachment download metadata and known-UUID denial to B/admin, blocked/self/unassigned contact and reassignment without history disclosure; `.out/issue516/db-repeat-green.log` (11 packages, with both supported database-test environment variables). |
| Backend regression | All other packages PASS on macOS. The two load packages bind additional 127/8 addresses unavailable on this host; both PASS under the production `golang:1.26.4-alpine` Linux image (`go-linux-load.log`). No product changes to the load harness. |
| Web full unit + production build | PASS: 482 files / 1607 tests (`web-all-final.log`), production Vue/TypeScript build. Includes ordinary route reuse and stale installation/account callbacks. |
| Flutter full unit | PASS: 1570 tests, one existing skipped test (`flutter-all-final.log`). Focused support contact/opener/drafts/IME/geometry tests PASS; targeted Dart analysis has no issues. |
| Contracts / traceability | PASS: 19 parity tests, OpenAPI 3.1 lint, unchanged 116 public operations; 39 requirements referenced. Approved Windows brief unavailable on this host: source validation used the committed requirement index only. Logs `contracts-final.log`, `traceability-final.log`. |
| QA harness | PASS: 10 policy/stack/native tests (`qa-harness-tests.log`). |
| Real browser support A/B/S + unrelated admin | PASS: `.out/support-contact/20261022-094009/report.json`, `mocks:false`, owned resources removed. Ordinary text/files/replies and realtime, no cross-pair history/file access, retained other DM draft, same pair on repeated entry, reload/history, operator self, replacement and blocked contact. Existing LiveKit voice transport remains connected on opening support. No external browser requests; axe-core found zero violations on the help button, pinned support row and named privacy region. |
| Broad real stack | PASS at 1440 (`.out/local-features/20261022-090619/web-real-stack-1440.log`) and 393 (`.out/issue516/browser-393-confirmed.log`), including ordinary DM/media navigation and owned Tempo. |
| Android emulator | PASS: `.out/issue516/android-final/runtime.json`; actual Go API auth, help → existing DM section/unassigned status, workspace/panels/logout. |
| iOS Simulator | PASS: `.out/issue516/ios-confirmed/runtime.json`; same actual API smoke. |

Required feature command was run:

```sh
./tools/qa/local_features/check.sh --feature support --feature auth --feature chat \
  --feature connection_status --feature screen --feature shell --feature voice \
  --base origin/master --real-stack
```

The initial aggregate report remains **FAIL**, rather than being overwritten: it captured a scoped-style contract error (moved into shared DM tokens), keyboard order before adding the help button to the test, a 4 px history-anchor timing failure (all 14 anchor cases passed on repeat), a Flutter compiler/test snapshot during an edit (fresh full suite above passed), and missing owned native text-channel fixtures. The compact mini-player assertion contradicted the existing mobile voice acceptance: it now checks the persistent dock and hidden room controls. Native setup creates its channel through the authenticated admin API; the iOS scroll/tap helper centers the disclosure above the fixed footer. Corrected named runs above supersede those individual failures; the old report is not labelled a blanket green run.

The first PR CI database profile caught a non-idempotent 0055 table/seed. The migration now uses `IF NOT EXISTS` and `ON CONFLICT DO NOTHING`; the actual PostgreSQL support test reapplies all migrations after assigning an operator and verifies that both account and revision survive. The earlier local migration integration had been skipped because it uses `TEST_DATABASE_URL`, whereas the DM fixture uses `VOICE_PLATFORM_TEST_DATABASE_URL`; the corrected runner sets both. All 11 nearest packages, including both empty/existing migration schemas, guild settings and usage-retention regressions, pass in `db-repeat-green.log`. The failed first CI attempt is retained, not represented as a pass.

CI on the corrected migration passed backend, Web, SFU, Android and Windows build. The Dart tests/analyzer passed, then exact-set capture publication correctly rejected the seven newly added support widget images because their names were not registered. The finite mandatory `VISUALS` inventory now includes exactly those seven reviewed synthetic names (133 total); regression tests require all seven and still reject an arbitrary `support-user-upload.png`. All 109 artifact-policy/Flutter-gate tests PASS (`capture-policy-green.log`), including rejection of an unregistered support image. No wildcard, privacy filter or source/integrity check was relaxed.

The additional assigned-contact native journey (`integration_test/support_qa_test.dart`, runner `tools/qa/support_contact/native.py`) reproduced a ListTile ink/selection visibility assertion under the real sidebar ColoredBox. The pinned row now has its own transparent Material, consistent with ordinary DM rows. A selected/busy sidebar regression first failed and then passed; all 14 focused support/draft widget/controller tests pass and targeted analysis is clean. Actual Android and iOS assigned support both pass: `android-pair-final/runtime.json` and `ios-pair-final/runtime.json` under `.out/issue516/`. These runs opened the assigned support from the footer, sent native composer text, uploaded/sent a file through the existing native API, received an ordinary operator HTTP reply over realtime, and reopened the same pair. Reports record source/diff/scenario hashes; device captures contain only synthetic data.

## Visual review

Inspected applicable source-sized synthetic captures: Web support empty/conversation/replacement at 1440, drawer/conversation at 393 and 320, enlarged root text 200%; Flutter pinned row/footer at 320/393/1440 dp and scale 1/2, 320 dp enlarged text with IME; actual Android and iOS unassigned support screens.

The help icon stays monochrome and secondary, separate from voice controls, with a 44 px target. The pinned row, unread count and ordinary composer fit compact widths. The privacy/replacement explanation scrolls within a bounded area, preserving composer space at large text. The long support prompt is the empty-history text; the existing short composer hint avoids clipping. Unavailable support keeps the mobile drawer open with its reason. Replacement is explained both in the DM list and in the new support conversation.

Before/After captures compare synthetic states (unassigned → empty support → ordinary conversation → replacement), **not an approved source pixel baseline**. No new screenshot baseline was approved. Other feature captures from the broad aggregate report retain their own review status.

## Explicit limits

Android/iOS assigned-contact sender UI and ordinary operator API reply were tested as described above; **native platform file-picker interaction and operator-side native UI** remain NOT_RUN. File upload used the existing native API, not a picker stub. Web A/B/S covers the ordinary operator UI and cross-pair ACL. macOS/Windows native runtime for this feature: NOT_RUN. Physical devices, hardware screen capture, screen-reader interaction and media quality/capacity: NOT_RUN. No release/physical gate is closed by widget captures. Existing screen/voice lifecycle remains the ordinary DM navigation path; no new capture flow is introduced.

Artifacts stay in ignored `.out/`; no private bodies/files/identifiers, credentials or generated media are committed. The support runner refuses non-owned origins/containers and removes its temporary accounts/resources. GitHub publication is a manual operator process documented in `docs/runbooks/support-contact.md`; no product GitHub POST/webhook/export code was added.
