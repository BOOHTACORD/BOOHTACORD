# Ticket closure evidence — 2026-10-29

All results are scoped to their executed platform and source. No production SQL,
failure injection, load traffic or user attachments were used for this packet.
The 43 consolidation decisions remain untouched.

| Ticket / protection | Executable command | Platform | Mandatory when | Result |
|---|---|---|---|---|
| #592 ordinary DELETE/UPDATE; immutable support identity/session fences | `cd backend && go test -json -count=1 ./internal/database/migrate` with owned `TEST_DATABASE_URL` | Windows + disposable PostgreSQL17.6; hosted database gate | Support guard/migration changes | `issue592.json`, `delivery592.json`; PR604 merged and delivered |
| #581 protected original download bytes/format/name in TEXT/DM; ACL/tombstones | Unit: `npm test -- --run src/conversation/protected_image_preview/viewer_download.spec.ts`; runtime command below | Windows Node24; Linux headed Chromium153 in WSL, actual Go/PostgreSQL | Viewer/card download wiring | `web/browser-result.json`: 12 downloads, all six scope/format cases PASS |
| #580 owned nav shortcut; editors/IME/dialog fences, focus and DM dedup | Unit: `npm test -- --run src/search/navigation_shortcut.spec.ts src/search/search_shortcut.spec.ts src/search/search_return_focus.spec.ts src/search/quick_jump.spec.ts`; runtime below | Windows Node24; Linux headed Chromium153 in WSL | Shortcut/focus/dialog ownership changes | `web/browser-result.json`: 1440/800/390 × Ctrl/Meta PASS, DM ID reused |

Executed full-app command on this PC (private tool SDKs are pinned locally):

```powershell
wsl.exe -d Ubuntu --exec /usr/bin/python3 /mnt/c/Users/egkur/.codex/worktrees/close-qa-regressions/BOOHTACORD/.out/closure/run_browser_linux.py
```

Runner text and LF hashes are retained in `web/runner-source/` and
`web/runner-sha256.json`; these are audit copies of the exact executed local files.
The runner asserts source revision/tree, builds the real app/API, creates only
owned containers/data and removes them in `finally`. Browser responses are not
mocked. Synthetic images are recreated from `make_images.py.txt`; their original
hashes, dimensions and codec frame count are in `web/fixtures.json`.

The SQL regression was RED on the historical behavior (DELETE0,nil), then GREEN
with forward0065. Historical0056 is unchanged. Hosted1694 backend test-completion
events have zero fail/skip, including all three new guard tests.

The search native-dialog counterexample is retained in
`web/native-dialog-runtime-red.json`; source89cf65 allowed Ctrl+K behind the actual
image dialog. Final sourced05922 rejects it and retains the nav launcher exception.
Earlier harness assumptions about hidden focus targets, POST response shape and
sidebar/search mode are environment/runner diagnostics, not product counterexamples.

All12 changed-view screenshots were inspected at source resolution: preview and
download/close controls fit; the search panel and focused input fit at all three
widths. Narrow Escape returns to the visible navigation toggle, desktop Escape
to its launcher. Generated images remain in ignored local output; hashes/raster
and observations are in `web/captures.json`. No new screenshot baseline was accepted.

Native Android/Windows media, GIF preview animation and global capacity/security
acceptance are not inferred from these Web results. Microphone/voice counters
cover the admin navigation page. Canonical local_features and final PR605 CI /
delivery are separate receipts and must pass before closing #580/#581.

Final targeted Web closure is recorded in `web/closure-result.json`. All 23 canonical automated
stages pass, including owned real stacks 1440/393; exact-master Build 40954061417
and automatic Deploy 40955588855 pass. Fresh public source/health are in
`web/public-final605.json`; source/schema/migration inventory/volume readback is
in `delivery605.json`. The earlier scope and failed-attempt reports retain their
recording-time status. The full canonical gallery remains REVIEW_REQUIRED; only
the 12 changed-flow images are declared visually reviewed. No baseline was approved.
