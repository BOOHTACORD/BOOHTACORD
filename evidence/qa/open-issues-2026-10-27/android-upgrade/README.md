# Physical Android signed-candidate upgrade

This packet is a source-bound QA check, not stable publication or full QA-13 closure.
The phone's current published APK is 1.0.45/2080, source
`9c221897fdefec8098f707d61ca5b6e8b28bb0bd`.
The selected dry-run candidate is master
`072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.

| Protection | Command | Platform | Mandatory when | Result |
| --- | --- | --- | --- | --- |
| Existing package, signer, monotonically newer ABI versionCode and exact source | `python -X utf8 .out/qa-goal/verify_android_candidate.py` | Local Windows APK verifier; real signed hosted artifact | Before installing the QA candidate | `summary.json`, `verified.json`, native contract and download receipts |
| Preserve app installation, original authenticated account and own DM operation | `node .out/qa-goal/native_upgrade_peer.mjs before`; `python -X utf8 .out/qa-goal/android_candidate_install.py`; `node .out/qa-goal/native_upgrade_peer.mjs after` | Physical Samsung SM-A576B Android16/API36 plus actual Windows Chrome receiver | Before accepting in-place Android upgrade facets of QA-13 | `device-before.json`, `install.json`, `peer-before.json`, `peer-after.json`, `summary.json` |
| Keep native discovery gates and no-skip policy | `Android Release`, workflow_dispatch on exact protected master with `dry_run=true` | Hosted Android/Kotlin and macOS native runners; pinned Flutter/Dart | Before using this artifact for QA | `ci.json`, `quality/`, hosted run40447079903 |

Install policy: exactly one `adb install -r` attempt after the full CI run succeeds,
the release publication step is skipped, local contract validation matches hosted
bytes, and all three APK signatures/versions are independently inspected.
No uninstall, app-data clearing, downgrade, release tag or publication is part of
this check. App session/private storage is not extracted.

An explicit native voice leave precedes package replacement. Actual native launch,
same-account message delivery, cleanup and SHARE_TEST restoration must be observed
afterward before claiming that upgrade scope passed. A package-manager success
alone cannot establish the preserved session or voice state.

Published crops preserve source resolution, hide conversation/identity and make no
audio claim. The human listener is unavailable; audibility remains NOT_RUN.
Older physical results retain their original APK source and are not reassigned to
the candidate. Two distinct public stable releases, other hardware/platforms,
acoustic/media quality, notification delivery and the full QA-13 matrix remain
separate requirements unless explicitly executed and recorded.
