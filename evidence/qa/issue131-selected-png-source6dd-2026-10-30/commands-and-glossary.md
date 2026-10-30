# Actual Web image-viewer deletion — scoped PASS

Final source: `6dd79c244e6cbd69bcfbd38a3fcb5727508e0933`; tree `f411320399273c487152f389d6c03019e0d391c3`.
Archive SHA256: `a313b3bd76076bf0e556facdb9deaa175993f4776a07fdc0190dc697100e3a67`.
Actual API image: `sha256:85e05e181c4f1a9b147721f7d64250f2010ebee08f7d778fb7f12e640d73b04b`.
Authoritative exact image/source values are retained in `attempt3/guards.json` and `verdict.json`.
Served HTML SHA256: `69c6330117c3c4d005a51d46b3caf4d4e05694a4c72699a930b48627e3f6fb51`.
Platform: Windows11 host / WSL2 Ubuntu / fresh headed Linux Chromium153.0.8010.12; normal TLS, ignoreHTTPSErrors:false.
No native Windows/phone/media/audibility acceptance. No new screenshot baseline approval.

## Command, protection, platform, mandatory trigger, result and location

The executed launch argv used these two local filesystem parameters: OWNED_NODE24 and OWNED_RECEIVER_ROOT. They are path parameters only, not credentials. Full local argv stays in the private command record.

```text
wsl.exe -d Ubuntu --exec /usr/bin/xvfb-run -a --server-num=147 '--server-args=-screen 0 1600x1200x24' ${OWNED_NODE24} ${OWNED_RECEIVER_ROOT}/prefix.mjs
```

OWNED_NODE24 is Node24.18.0. `prefix.mjs` reads the exact attempt4 browser-prefix.json, executes the disposable bwrap/private NSS argv, and starts main.mjs. It does not start services or create accounts/DMs.

| Command / actual action | Protects | Platform | Mandatory when | Result / location |
|---|---|---|---|---|
| Node `--check` six bounded runners; repeat only changed files | Runnable harness integrity | WSL Node24 | Before each run | PASS; runner bytes/hashes in each attempt runner-hashes.json |
| Source/handoff SHA checks and fresh real Web200 + anonymous session200 | Wrong/stale source, wrong origin, stale profile | Linux headed Chromium | Before any login or fixture | PASS; attempt3/guards.json |
| Three ordinary UI logins; protected session role/account/pair checks; secure HttpOnly cookie properties | Session ownership, member roles and DM scope | Same isolated browser | Before touching existing pair | PASS; no cookie values saved; guards.json |
| Actual file input and one UI Send per scope | Genuine full-app upload/render path | Actual Vue app, real Go/PG17.6 | Before viewer lifecycle claim | HTTP201; exact author/scope/attachment bound; receipt.json assertions |
| Original/preview fetch and original SHA on author+peer | Both authorized sides, original byte identity | Same normal TLS/browser sessions | Before deletion | Both200; original SHA matches owned PNG |
| Outsider/anonymous protected URL reads | DM privacy and public-TEXT distinction | Same isolated browser | Before scope/ACL claim | DM outsider404; public TEXT outsider200; anonymous401 |
| Real open viewer; actual Escape; existing opener focus check; reopen at390x844 | Visible pixels, dismissal, focus return, narrow bounds | Both MEMBER pages, TEXT+DM | Before deletion acceptance | PASS; two wide and four narrow Before originals |
| Desktop hover -> visible Delete -> actual browser confirmation | Author UI path while both viewers stay open | Own author control tab | Triggering deletion | DELETE204 twice, no fallback in final; receipt typed assertions |
| Observe live UI; previous blob fetch; exact history tombstone; protected URL reads | Stale pixels/object URL/attachment revocation | Both participant pages | After exact author deletion, without refresh/nav | Images/dialogs gone; previous blob not fetchable; exact tombstones; both404; four After originals |
| Own logout POST and session GET readback | Exact own-session cleanup | Same three normal MEMBER contexts | Finally, each attempt | Nine total logout204/authenticated=false; six exact fixtures cleaned |
| Await own browser.close; wrapper completion; scoped /proc and X147 socket/lock readback | Owned process/display residue | WSL only | Before infrastructure handoff | PASS0; own Node0, Xvfb1470, socket+lock absent; cleanup-verification.json |

## Immutable assertion glossary

`viewer_case.mjs:41` assigns `oldBlobReadable` from `fetch(previousBlobURL).ok`; a fetch error becomes false.
The raw assertion names author_old_blob_revoked and peer_old_blob_revoked are misleading predicate labels.
Their immutable actual=false / expected=false means **old blob still fetchable=false**, hence the URL is no longer fetchable. It does not mean revocation=false.
The new verdict names this observation oldBlobStillFetchableAfterDelete=false. No immutable receipt or assertion was renamed.
Runner SHA256 for this edge: `6608836fd1bc26f676ce6f6af1bd8479fff1b7f7151a68f3ef99e7a613b470e9`.
Source lifecycle edge: ProtectedImageViewer -> useProtectedImagePreview.cancelPreview -> revokePreview; onBeforeUnmount cancels and revokes its object URL.

Escape/focus PASS is the ordinary close control while the opener still exists. After deletion that opener is removed: focused tag BODY and zero open dialogs are recorded as **no modal trap only**. No post-delete focus-fallback PASS is asserted.

## Provenance, visuals and cleanup

Final `attempt3/receipt.json` SHA256: `2248e02de3915de852200972b3fab72a0ef9468a24d082c45f394fe9b64b4b36`.
Root independently reviewed all10 originals: two1440x1000 and eight390x844. Images, header Download/Close and footer are in bounds; After has no image/overlay, exact tombstones visible, composer unobstructed.
Root original review: `root-original-review.json`, SHA256 `f9d9aef42dfa74d818622d211c5d6785fc1c80dda4a1e8c88c0bec908d3150bd`.
Original PNGs stay private under `attempt3/private/`; exact hashes/dimensions are in the final receipt. Bodies/fixture identities are private only.
Browser attempts1/2 retain their full receipts/runners/screenshots and successful exact cleanup. Their hidden desktop mobile-toggle and render-timing failures are harness diagnostics; they are not product failures or silently discarded runs.
Final attempt3 has90 typed assertions PASS and two actual author UI deletes, zero fallback deletes.
Across three browser runs: six owned image messages are blank tombstones with attachments[]; nine normal UI MEMBER sessions logout204 and authenticated=false. No accounts or DMs were created by this browser packet.
Final process/display absence at2026-10-30T01:29:09.045Z is in cleanup-verification.json. Stack/holder cleanup remains local_qa_deploy/root-owned and separate.
This is a scoped PNG viewer lifecycle result, not full I131.C5 or whole #131 acceptance. Actual OS chooser/download-event, all formats, admin/revoke, other platforms and acoustic gates are not claimed.
