# FE-53: protected Web image viewer

Started 2026-11-25; acceptance continued 2026-11-26. Base: `73912f20a5b729a4f8175669ec30cb4bbfbdc9c4`.
Scope: Web TEXT/DM viewer only. No API, authentication, ACL, Flutter, media or deployment change.

## Preservation and counterexamples

The original 12-case browser baseline had 6 PASS / 6 FAIL: scope changes retained old bytes,
non-focusing activation returned to an unrelated button, and Tab escaped the modal.
The original preview lifecycle suite had 1 PASS / 4 FAIL: missing abort/closed/disposed
admission and an obsolete 404 poisoning newer state. Original logs are retained under
`.out/viewer-baseline.log`, `.out/preview-unit-before.log`; no screenshot baseline was approved.
Markup/styles, protected same-origin/no-store PNG preview, original-only download,
retry and unavailable/deleted presentation were preserved through the move to
`clients/web/src/conversation/protected_image_viewer/` with compatibility forwarders.

## Focused results

- Preview lifecycle, attachment-card and original-download tests: 14 PASS.
- Windows Edge 158.0.4370.33, owned fresh contexts: 26 browser cases PASS.
  TEXT/DM at1440/393/320px; loading, 403/404/410/500/decode failure, retry,
  Escape/focus, keyboard containment, cancelled/stale requests and immediate reopen.
- Production Web build with `VITE_PUBLIC_ORIGIN=https://localhost:4810`: PASS.
- Actual isolated PostgreSQL/Go API/HTTPS and built Web, no mocked network or stored
  attachment rows/files: `python -m tools.qa.protected_image_viewer.run` PASS on
  Chromium153.0.8010.12; the same scenario PASS on Windows Edge158.0.4370.33.
  Synthetic MEMBER-to-MEMBER uploads in TEXT/DM:2048x1280 original normalized to
  1024x640 preview, original download bytes identical at all three widths.
  Both participants receive200; anonymous401; wrong scope404; ADMINISTRATOR
  outside DM404. Live peer deletion closes an open preview; both paths then404.
- The preview-mocked fixture cannot intercept the browser download network path;
  its download event/URL/name checks are complemented by real-server byte checks above.

Commands/logs: `.out/windows-viewer.log`, `.out/viewer-unit-after.log`,
`.out/web-build.log`, `.out/linux-real-stack/result.json`,
`.out/windows-real-stack/result.json`. The committed real-stack scenario is reproducible.
Only synthetic QA accounts/files were used; sessions/passwords are not retained as evidence.

## Visual and platform scope

Original-resolution desktop/mobile images were reviewed in Chromium and Windows Edge: complete image, visible close/download controls, intentional filename ellipsis and readable wrapping footer at320px; no viewport overflow. Initial fixture captures sometimes preceded paint and were not accepted as baselines. The final fixture waits for image decode and two animation frames; its26 cases pass again on Windows; the real-server journey passes again with that capture readiness. Canonical CSS is unchanged after newline normalization. No new
reference images or generated media are committed. Existing Flutter viewer behavior
and FV2-022 acceptance remain separate. Android Chrome runtime is BLOCKED: its QA
AVD lacks its Google system image; the available AOSP WebView launch was rejected
by automatic tool policy. No physical Android, iOS/macOS, installed Windows Flutter,
media-quality or production deployment claim is made.

## Required integration gates

- Full native contracts PASS on the original base:1870 Python tests,28 declared platform/environment skips; contracts, links, topology, Compose, SBOM and traceability checks pass. No skipped Go acceptance is claimed.
- Web unit suite:602 files /2087 tests PASS. Registered accessibility suite PASS, including all26 new viewer browser cases.
- Registered full Web acceptance was started on the original frozen validation checkout. One control-consistency guild zoom2880px case timed out waiting for its field; its entire unchanged26-case suite then PASS. The original failing report remains retained. Other profiles and actual1440/393 lifecycle runs were still running at this record's initial commit; final observed results belong in the PR.
- Base advanced to `f7332715ae1671a0c548bb0c3dd0bc0eb79cfa56` (PR857, delivery smoke only), fast-forwarded without changing this packet. Its37 focused Python and6 Node checks PASS. Viewer production source is unchanged.
- Full native contracts re-run on the updated base:1877 Python tests,28 declared skips; all native commands PASS. The subsequent explicit viewer catalog mapping and its generated output pass30 focused catalog/ownership/projection tests, transition validation and generation check. No new runtime path is unowned.
- The expanded registry run retains one unrelated screen-baseline BLOCKED case: its generic component invocation has no isolated publisher/viewer tokens. Hosted frontend SFU and actual acceptance remain required, rather than treating that skip as a PASS.
- Preflight in the native Windows checkout passes whitespace, parity registry, product-map/flow generation and traceability checks. The Linux copied worktree's initial whitespace check rejects CRLF copied from Windows; that diagnostic is retained rather than described as a code failure or a successful Linux preflight.
- Exact-head hosted CI remains required before merge; it is not certified by this pre-commit record. No test, policy or baseline is weakened.

## Canonical production source fingerprints

SHA-256 over LF-normalized UTF-8 bytes, matching Git text blobs:

- `clients/web/src/conversation/ProtectedImageViewer.vue`: `9081b718a6ae9d9a84995a5600d955920dac167417648113647766f0d9d190e6`
- `clients/web/src/conversation/protected_image_preview/use_protected_image_preview.ts`: `416f67fa90ea0b5f4c2aa1f1aad9597b0f3367d03c5906673cd86c4cec83f94c`
- `clients/web/src/conversation/protected_image_preview/viewer.css`: `32bab2ce933f414627641aacf63200a6aab72d1590ccbb8e5259e5e1b86a08ca`
- `clients/web/src/conversation/protected_image_viewer/component.vue`: `c8a89c059a4ca696f6b8c36fafa359499db81f6760fc5ee5e15c8d3939121bbb`
- `clients/web/src/conversation/protected_image_viewer/dialog.ts`: `a645e3184e4e6d49d0992e0205423790103017a536dc845edae3b4f5a75804cb`
- `clients/web/src/conversation/protected_image_viewer/preview.ts`: `486134105fef697872c689f1ad2bcae7d5b8d3115d80dfe5e7642a418b9ba716`
- `clients/web/src/conversation/protected_image_viewer/viewer.css`: `5206379ba13504f7b6d30d0f560c5aefa522348bcea3372f61090d3c8e3765e7`

The earlier partial [QA-20 record](../flutter/qa20-web-attachment-image-viewer-2026-09-27-001.json) remains unchanged as historical evidence.
