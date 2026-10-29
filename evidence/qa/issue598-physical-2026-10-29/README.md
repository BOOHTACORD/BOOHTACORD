# Physical #598 acceptance, 29 October 2026

**PASS, scoped to the original own attachment-only JPEG/GIF bubble bug.**
Samsung SM-A576B / Android 16 / actual 1080x2340 captures.
The installed signed APK is 1.0.47+83, ABI arm64-v8a, versionCode 2083,
SHA256 `2eace5a664b864d412590b96d1fc2b717919a1a560a1d5566e19700630f7981b`.
Its verified release certificate is
`394e369de2d566b4897493ee498da2f27745e514c49ca88c6489b0b0a811212b`.

Fix PR #599 merged as `b4d31188b56d61f8a6b6c4ed26ba29d5f528a3c8`.
The actual candidate is trusted descendant master `f370396c468d26588cb934f8262b2ee7f4801044`;
the Send/lifecycle/delete regression leaf, tests, version and signing edges are unchanged.
[Accepted Android Release run](https://github.com/Egkurilov/BOOHTACORD/actions/runs/40882811704),
attempt 1: all six jobs SUCCESS; publisher SKIPPED. All four current-attempt
profiles and the actual signed APKs/contracts were independently byte-verified.
The later redundant run 40936213972 was cancelled by its owner and supplies no PASS evidence.

| What is protected | Command/action | Platform | Mandatory when | Actual result |
| --- | --- | --- | --- | --- |
| Exact approved installed source, signer, app ID and monotonic build | `apksigner verify --print-certs`, `aapt dump badging`, `adb shell dumpsys package ru.boohtacord.app`; exact APK SHA256 and 20 source-contract comparisons | Host observer + physical Samsung | Before accepting a candidate | PASS; signed-candidate.json, acceptance.json |
| Fresh native account/DM binding without extracting native cookies | Own peer standard secure login, new nonce, native explicit reply; verify server author and exact existing pair | Production HTTPS + native Android | Before image mutations | PASS; acceptance.json; native session preserved |
| Real attachment-only upload and painted own JPEG card | Native DocumentsUI selects the exact new local Downloads file; uploaded pending chip; one explicit Send; source-resolution review and four-region pixel oracle | Physical Android | Closing #598 JPEG criterion | PASS; formats.json; 774 B / 64x48 / 1 codec frame; original and preview HTTP 200 |
| Real attachment-only upload and painted own GIF card | Same native sequence, separate exact own GIF; one Send | Physical Android | Closing #598 GIF criterion | PASS; formats.json; 205 B / 32x32 / 2 original codec frames; original and preview HTTP 200 |
| Paint oracle rejects the wrong image | Four known interior card regions compared with canonical fixture; wrong palette/halves must fail | Actual Android screenshot, ICC converted to sRGB | Before accepting visible image pixels | PASS; JPEG max RGB errors 0/1/0/1, GIF 0/0/0/0; tolerance 14; formats.json |
| Protected attachment URLs require authentication | Anonymous GET of each owned original and preview, no credentials, default TLS | Public production HTTPS | Before claiming scoped ACL preservation | Four HTTP 401; anonymous-acl.json; not a nonparticipant/admin DM test |
| Native author delete clears content and revokes peer URLs | Exact API-bound own native row -> Delete -> confirm; canonical tombstone and protected peer GET | Physical Android + normal peer API | Before accepting lifecycle cleanup | PASS; JPEG/GIF body blank, attachments empty, original404 and preview404; formats.json |
| Cleanup changes only owned temporary objects | Native delete own reply/images; ordinary peer DELETE own challenge; SHA-guarded exact two device files; revoke only new peer session | Android + production own peer | Before ending this packet | PASS; 4 messages deleted, 2 files removed, 1 session revoked; 45 baseline records unchanged; cleanup.json |
| Current catalog availability still matches source after later server changes | Exact Windows/direct/stable/x64 and Android/direct/stable/arm64 public read-only GET | Production HTTPS | Rechecking earlier #249 availability fix | PASS at 19:24:16 UTC: both HTTP200, no-store/nosniff, revision29; public-catalog-current.json |

No History Refresh preceded either positive own-card frame. JPEG required four
explicit reveal swipes, including redundant swipes from an overstrict observer
which expected ImageView instead of Flutter's named clickable View; GIF required
one swipe. Passive visibility/autoscroll is not claimed. The immediate GIF frame
showed only a 22-pixel row strip; merged filename semantics were not accepted as
painted-image proof. Full cards and known pixel patterns were separately verified.

Both accepted frames show the recovering-realtime banner. No router/network fault
was injected. Realtime transport is UNPROVEN and no cause is assigned. After the
peer deleted its challenge, the native cached nonce remained until one ordinary
cleanup-only History Refresh. The final UI has an empty composer and no own test
payload semantics; this does not upgrade realtime to PASS.

GIF animation/native peer UI/admin DM ACL and the canonical local_features harness
are not covered. The prior harness bootstrap remains BLOCKED; full QA #62 remains
OPEN. Backend deployed source and the configured native URL string were not read;
the production data-plane account/DM binding was established by the fresh exchange.
The pre-update APK source is UNKNOWN; older physical FAIL receipts and code RED
remain unchanged. No 43 consolidation decisions were applied.

Screenshots, payloads, names, IDs, sessions and raw commands remain in the private
local packet. Only measured hashes, finite metadata and command/procedure mappings
are committed. artifact-receipts.json retains eight independently measured ZIPs;
helper-hashes.json identifies the executed local controllers. SHA256.json hashes
the nine evidence JSON files as exact Git/LF bytes; this README is explanatory prose.
