# SDK source integration checkpoint — 19 October 2026

This is a **partial, source-specific checkpoint**, not a release or whole-EPIC PASS.
PR #420 SDK head `3efd07e0480be73418bc224841d0edcb413021db` was tested at actual
checkout `6a25807060b53dbd455c8dd4d3adda4da95827f6`, base
`c4af4e2479f02c5d21c6b05f300b000aaf7a7d39`, tree
`f692b4537bacad91c4cc71ede08ad05483a39209`. The preview parents and tree were
verified with Git. Earlier cc32 acceptance remains separately frozen in
`hardening-hosted-2026-10-19.json`; neither receipt attests subsequent edits.

## Observed hosted results for 3efd07e0

[CI 39176086072](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39176086072)
completed all seven core checks successfully: changes 117819065478, contracts
117819065698, backend 117819099574, Flutter/Android 117819099586, frontend
117819099666, Windows 117819099687 and ci-required 117824469537. Contracts ran all
613 Python tests successfully on Linux (21.220 s); the same suite passed locally
on macOS (39.569 s). Actual Windows logs confirm the new cold SDK install and
Flutter/Dart/framework verification, followed by real native builds and GUI tests.
The bare-Windows-bash failure from preceding SDK head 00ec7935 was fixed by
resolving Git Bash explicitly; no WSL installation or weaker gate was used.

Additional checks: bounded actual SFU
[39176085963](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39176085963),
lifecycle [39176085949](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39176085949)
and isolated signed rollback
[39176086067](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39176086067) succeeded.
**Next-client [39176086082](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/39176086082)
failed** waiting 20 s for the newly posted reply row, after uploads and protected
unread checks passed. Therefore the combined candidate was not accepted or merged.

## Downloaded evidence and visual scope

ZIP digests were checked before bounded path/symlink/size-checked extraction.
Raw logs, images and service data are not committed.

| Evidence | Artifact | ZIP SHA256 | Validation / review |
| --- | --- | --- | --- |
| Windows GUI | 12154614713 | `129e2faa013268e6a22e9b9f7b6acf2d8f1d0cd0abfcafc6258785e853ae3e62` | Strict four-case result and checkout verified; eight capture hashes verified. Four changed 1008×720 originals viewed, four files byte-identical to earlier reviewed originals. Whole chooser footer/Close/Cancel/disabled Start visible; Escape restores focus and preserves the connected muted listener and lease. No source/audio publication or updater claim. |
| SFU | 12154502510 | `ac6d216b77d6f681839dcd0c099a333625f4877c1cb77489900946f5a8ca163e` | Exact checkout, actual API/PG/SFU, bounded 1/20/100 virtual HTTP observers, one RoomService call each, error recovery and owned cleanup verified. Not real media users or capacity evidence. |
| Rollback | 12154383847 | `b6c20f808e1f84a4d1dbb9723bf533105b8a4dcaed6e3df323f28aaefa9f163c` | Strict acceptance validator, ten browser observations, 21 harness and 35 builder source hashes verified. Ten capture hashes: seven unique 1200×800 originals viewed and three identical files bound by hash. |

Rollback used actual successful master producer 4261f720 / Build server 39171728724,
previous bfea46b6 / 39155159380. Qualified gate IDs, runtime-input parity and retained
source trees were checked. The known 44 px maintenance banner still pushes the
account footer and composer file-limit hint below the viewport on both retained
versions; this is not a whole-layout PASS. Stable phases retain visible account,
composer and attachment controls. This isolated QA-key rehearsal is not production
rollback, native publishing or physical media acceptance.

## Navigation diagnosis and pending changes

A separate hosted read-only fixture branch captured bounded numeric/boolean page
state and synthetic screenshots on failure. It suppresses exception contents and
resource IDs in logs; three focused native-file/privacy Node tests pass. Its
branch-specific push trigger is diagnostic-only and is excluded from PR #420.

Unchanged navigation criteria passed at diagnostic head 285ef810 / run
39177367861 (artifact 12154634498, ZIP
`61a07769917f3946215c68e85f52c22f9a49d570331da2a70701304c83e47136`;
32 source and four capture hashes checked). That establishes intermittency, not
an explanation or a PASS for 3efd07e0. The local macOS diagnostic failed earlier
in unread handling and did not reach navigation; it is not a reproduction of the
hosted reply failure. Its owned services/profile were cleaned up.

The fixture now first awaits the new row at the latest position before choosing
the scroll origin; HTTP completion alone does not commit the virtualized DOM.
All reply-return anchor/offset/focus, voice lease, ACL and search assertions remain,
with the same timeout. Readiness-only diagnostic head 8065e0a3 / run 39177952697
passed. An explicit SQL-only unseen row additionally witnesses that search does
not consume history which was never delivered/rendered. Its first diagnostic
(a6237b05 / 39178039024) failed in the new check; `psql -At INSERT RETURNING`
returns a UUID **and** a command tag. The first UUID row is now extracted, matching
the existing fixture convention. This output contract was verified on an owned
PostgreSQL 17.6 container with network disabled and no published ports; the container
was removed. Fresh acceptance for the parsed witness and integrated PR remains
pending. No failed receipt is relabeled as a later source's PASS, and the precise
cause of the initial intermittent reply failure is not claimed proven.

#386 and #392 remain open for their outstanding acceptance. Native publisher QA,
external environment/tag/runner isolation and hosted cache measurements are not
proved by these core checks. The owner configures #385's required status personally;
no repository protection, credential or Keychain setting is changed here.
