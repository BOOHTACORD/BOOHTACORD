# FE-55: Web DM image clipboard

Base: `57bed06e68d26fa835d25bd0c612c69e28631efa`. Web only; existing API/ACL, dependencies and native Flutter remain unchanged.

## Preserved behavior and bounded change

The DM composer already extracts images, replaces selected text synchronously, uses a scoped managed queue and waits for explicit Send. The actual DM uploader discarded status/code in a plain Error. As a result the shared queue could not recognize real507/INSUFFICIENT_STORAGE. Preserve the legacy diagnostic text and add structured status/code; move the implementation into the child attachment_upload leaf with the old path forwarding and the picker importing its native child. Historical QA-21 and FE-54 records are preserved.

Before production edits: nearest unit11 cases produced9 PASS /2 FAIL for missing structured error fields and the queue explanation. All six existing attachment API tests passed. Browser baseline8 PASS /1 FAIL;507 remained technical text. All six320/393/1440px,100/200% geometry cases passed, so DM layout was preserved and no CSS change was made.

After the error fix:27 nearest unit cases and18 TEXT/DM browser cases PASS. A stronger return-to-scope test then reproduced loss of a ready attachment in both TEXT and DM (2 FAIL): independent reset callbacks cleared the newly restored draft before the scope callback could restore its queue. Both native picker bindings now coalesce scope/token changes. Final21 Edge cases PASS, including12 new DM cases and four507 error-layout combinations at1440/393px and100/200% text. Test events are synthetic and are not OS clipboard proof. Cases cover selection/co-pasted text, no automatic send, pending A/B scope switch without old file IDs, explicit507 retry, eleven-file rejection and inclusive25MB/oversize validation.

## Real runtime and visual acceptance

Owned Go/PostgreSQL/HTTPS acceptance PASS on Chromium153.0.8010.12: all eight1440/393 groups with trusted Ctrl+V and no network mocks. Mixed text/selection and attachment-only sends are explicit; actual protected downloads match the actual pasted PNG hash after browser normalization. Another independent participant receives the message, original bytes and normalized nosniff preview; a third MEMBER and a nonparticipant ADMINISTRATOR cannot read history/search/original/preview or upload. A valid file from DM-A cannot attach to DM-B. Two held real channel uploads reserve50MB; another DM participant receives507, release restores capacity, and explicit retry sends the retained image after replacing OS clipboard. A ready retry attachment survives B/A navigation with the exact same ID. Pending transport cancellation leaves0 server-reserved bytes at both widths, so partial server-stream cancellation is not certified. Drafts for A and B are separately restored. Owned resources are removed.

Final TEXT helper/binding regression PASS at1440/393 (six trusted clipboard/API groups), including ready-file return before attachment-only send. Full Web units2096/604 files, production build, registered accessibility163/163 and native contract runner PASS. The native Python suite declares28 platform/environment skips; no skipped native/media gate is inferred as PASS. Remaining selected registered profiles, authenticated core journeys and exact-head hosted CI are still completing at this pre-commit record. Their final results are recorded in the PR before merge.

All22 focused captures were reviewed at source resolution:10 Edge DM states (including four507/large-text combinations),6 actual DM and6 actual TEXT. Text/selection, image metadata and retry/remove/Send controls remain readable/reachable at320/393/1440px and100/200% text; known error copy wraps without hiding the editor. Native snapshots show synthetic image thumbnails and correctly scoped drafts after navigation. Transient background roster/service hints or navigation refresh/tooltips do not establish global shell/media readiness. No screenshot baseline approved. No physical/native Flutter or Apple clipboard/media acceptance is claimed.

The first owned launch stopped at a QA-script syntax error before browser checks. The next stopped on a missing navigation-tab action; a later run passed all four1440 groups but stopped during393 account setup. These failed harness runs are retained and do not certify the full journey. The final fixture registers four necessary member accounts, reusing the independent peer/outsider while retaining a fresh uploader per width. No production rate limit, required role or ACL assertion was weakened. Both widths now pass.

## Production fingerprints

SHA-256 over LF-normalized UTF-8, matching Git text blobs:

- `clients/web/src/direct_message/attachment_upload/client.ts`: `dfa8b6bc0b0a8ad9e00efd52262b75629a913a0636e4e02e036303ad6a4c220e`
- `clients/web/src/direct_message/direct_message_attachment_upload_client.ts`: `967ec7a5e5733a311cd9579d210a52a67ed028aa53e8d37253f9ce93b74f9ac4`
- `clients/web/src/direct_message/DirectMessageAttachmentPicker.vue`: `08bb778b61d116bb381ce8df5f56046243a891670173f0eefabdd4f8f6304ed3`
- `clients/web/src/conversation/TextMessageAttachmentPicker.vue`: `3da992987a150d2f6d7fb6657c64f8d65c8516051952e0e6651687b86ad9e44d`
