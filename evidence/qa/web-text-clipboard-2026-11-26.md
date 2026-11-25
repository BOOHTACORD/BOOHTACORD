# FE-54: Web TEXT image clipboard

Base: `50782f7127749d5876700e3ba215e4815b5a894d`. Web only; no API/ACL, dependency, native Flutter or deployment change.

## Before/after behavior

The original helper already extracts clipboard images and preserves accompanying plaintext. Its former source-string wiring assertions did not prove browser behavior. They are replaced by behavior tests and an actual built-Web/API journey. The historical QA-21 PARTIAL record is preserved.

Original focused baseline:12 unit PASS /1 FAIL and4 browser PASS /1 FAIL. The failure confirms a real507/INSUFFICIENT_STORAGE leaves the user with a technical code instead of an actionable storage explanation. The focused change maps exactly that code/status in both per-file and global queue errors; other diagnostics, retry/send/cancel semantics and file identities are preserved.

Initial after:22 nearest unit tests and5 Windows Edge browser cases PASS. Visual review then found that the393px editor had width0 and hid its nonempty value. A stronger six-case layout baseline at320/393/1440px and100/200% text produced4 FAIL /2 PASS. A TEXT-only populated-upload-queue minimum editor width fixes those four cases; the final9 browser cases and23 nearest unit cases pass, including the inclusive25MB boundary. Cases cover mixed image/text at a selection, no automatic send, failed507 retry using the same image, A/B scope cancellation and no prepared-ID leak, eleven-file paste and rejection above25MB before transmission. Windows component ClipboardEvents are synthetic and are not claimed as OS clipboard proof.

Commands: Vitest on clipboard_images.spec.ts, upload_queue/, text_attachment_queue.spec.ts and text_attachment_upload_client.spec.ts; Playwright accessibility config filtered to clipboard_paste. Baseline/after logs and captures are ignored under `.out/`.

## Actual clipboard and server acceptance

`python -m tools.qa.clipboard_paste.run` uses an owned Xvfb display/clipboard, trusted Control+V, actual Go/PostgreSQL/HTTPS and a labeled capacity-bounded tmpfs. Two held real uploads reserve50MB without filling the disk; another account's clipboard upload must receive507. Releasing those connections restores capacity, after which the same queued file is retried explicitly. Original download hash is compared to actual pasted image bytes after browser PNG normalization. A real throttled request is aborted by a channel switch and reservations must return to zero. Initial fixture incorrectly required a25MB server reservation before switching; that run failed after the positive mixed-paste and actual507/retry cases. Chromium may delay the whole request before API admission. The corrected measurement records whether0 or25MB was admitted and requires zero after cancel; it does not certify server-side partial-stream cancellation when admission is zero. Original failure logs are preserved.

Runtime PASS on Chromium153.0.8010.12: all six desktop/narrow journey groups; actual clipboard input is trusted. Before explicit507 retry the OS clipboard is changed to plaintext; the retained image still downloads with the original pasted hash. The pending transport had0 admitted bytes reserved at both widths;0 is verified after cancel. This does not prove partially received server-stream cancellation. All owned resources are removed.

Original-resolution Before/After reviewed: the previous393px field was invisible with width0; the final text and caret area remain visible beside uploaded/failed queues. At320/393px and100/200% text, names/status/buttons wrap, the draft is readable and Send remains reachable. Desktop geometry is preserved. No screenshot baseline was approved. The QA stack has no joined SFU; transient maintenance/roster hints in background captures do not establish voice or global shell recovery.

Full Web unit/build (2091 tests in603 files), native contract checks and30 focused catalog checks pass. The first registered accessibility pass retained3 dynamic-import failures in unchanged admin/profile fixtures and148 PASS; an unchanged full rerun passes151/151. The original report stays FAIL. The unrelated screen-profile baseline remains BLOCKED because publisher/viewer tokens were not provided (19 PASS,1 skipped); no media baseline is certified. Remaining registered profiles and exact-head hosted CI are still completing at this pre-commit record. Final observed CI and expanded-report results are recorded in the PR. These gates are not closed by a build or synthetic ClipboardEvent. No physical mobile/Apple/native Flutter or FE-55 DM clipboard acceptance is claimed.

## Production fingerprints

SHA-256 over LF-normalized UTF-8, matching Git text blobs:

- `clients/web/src/conversation/upload_queue/failure.ts`: `204ddd2b5a0c25200d3b5b1d875ce24c73dca2e55c486a0a021fb202f37fffa9`
- `clients/web/src/conversation/upload_queue/queue.ts`: `57032842cdd661a5adb5e979627d32f8a56487cd7cae7ac25b3772dcd6cf8d17`
- `clients/web/src/conversation/upload_queue/runner.ts`: `245968c375057fe26eccab0eeeffadc764a968af960803a20d535297f19f03b6`
- `clients/web/src/conversation/upload_queue/text_layout.css`: `cdc9f9443f6a068eb03e0efe7e9ab38f029380bb541237996bc93ce663d7fb0f`
- `clients/web/src/style.css`: `4d9858cfac731649ea6b4ff04cc3bbb0081e25b81b10e3470c808f545bb7de88`
