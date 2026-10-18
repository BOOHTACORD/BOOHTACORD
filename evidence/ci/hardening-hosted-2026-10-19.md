# #386 hosted candidate regression, 2026-10-19

This is scoped candidate evidence, not complete CICD-12 or epic acceptance.
[PR #420](https://github.com/Egkurilov/BOOHTACORD/pull/420) head
`cc32d1d80ae72a2bc56a6128838c00e3f9513e75`, actual checkout
`bbad9e072076f723b478dffb1efbec2350d5a7af`, tested base
`a6d725bd40d7a3c7c2c53d9877d3ccbf12e5c773`, tree
`7d486a5608bf7a17eb3f44bb3909dec8576c2524`. Checkout parents/tree were fetched
and verified against the exact candidate. Later master
`4261f7208fdf9a486644ee967aab931df432aae9` contains independent Web changes;
these results do not attest that later application source.

| Actual workflow | Result |
| --- | --- |
| [CI 39171014369](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39171014369) | seven SUCCESS checks: selector, contracts, backend, Web, Flutter/Android, Windows and ci-required |
| [Signed rollback 39171014344](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39171014344) | SUCCESS, actual isolated signed releases and two browser observers |
| [Next client 39171014459](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39171014459) | SUCCESS, actual uploads, unread/context/ACL and voice retention |
| [SFU 39171014421](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39171014421) | SUCCESS, actual API/PostgreSQL/RoomService; no media capacity claim |
| [Lifecycle 39171014347](https://github.com/Egkurilov/BOOHTACORD/actions/runs/39171014347) | SUCCESS execution; additional lifecycle captures not manually reviewed here |

All eleven exact-head checks were complete and successful, with no omitted page.
The adjacent JSON retains job IDs and immutable source bindings. Local checks at
this candidate: 592 Python tests, 22 focused security tests, two native-file Node
tests, workflow policy and source-pinned actionlint PASS. Requirement traceability
is PASS_INDEX_ONLY (39 IDs; approved brief unavailable on this host).

The first head's real SFU/next-client failures were corrected before this run.
See the candidate's `hardening-acceptance-fixtures-2026-10-19.md`: report identity
now hashes the registered owned container's executable, and uploads select
identical real local files instead of large CDP buffers. No acceptance, file size,
HTTP assertion, timeout or privacy condition was relaxed. Cancelled, pending or
failed prior results were not counted for the revised head.

## Artifact and visual review

ZIP digests, bounded flat archive paths, source revisions and every image hash
were checked. Next-client's 30 source hashes and rollback's 21 harness plus 35
builder hashes match the fetched candidate. The rollback runtime receipt and all
ten browser observations passed the unchanged strict evidence validator. Its
current/previous images use actual master sources
`f65f22835d2c32134a2f1eaa2f9855fafa112509` (run 39168026909) and
`bfea46b61c3bc641098caf7c35be8c4be798af59` (run 39155159380). Both compatible
bundles use an isolated QA signing anchor. No production key, new production
trust anchor, data copy/restore point or production rollback was used.

Twenty-two original-resolution images were inspected: eight Windows 1008x720,
four next-client 1440x900 and ten rollback 1200x800. Windows retains dialog/footer
and quality controls, Escape focus, mute and the same connected listener; Start
is disabled because no source is selected. Upload cards, channel/DM composers and
context-return controls are visible. Search context retains its selected target
and connected muted voice dock. Rollback stable phases retain both accounts and
the attachment card; both maintenance transitions show the warning to both views.

Existing visual limit: in all four maintenance captures the 44-pixel banner pushes
the account footer and composer helper line below 1200x800. This is already noted
in `evidence/release/qa12-live-compatible-rollback-2026-10-18.md` and is visible on
both retained Web versions. Functional rollback/data invariants PASS; no whole
layout, physical/native/media or capacity approval is assigned.

Only hashes and controlled public numeric/boolean/enum observations are committed.
Images remain in 30-day Actions artifacts; after expiry exact retrieval is NOT_RUN.
No raw logs, media, credentials or application contents are committed here.

## Remaining acceptance

#386 and #382 stay open. Native publishing QA and actual environment, tag and
runner isolation still need evidence; static guards do not prove those settings.
Required-status configuration (#385) remains owner-managed. Readback is unavailable
(403 API, signed-out settings UI); an empty ruleset list does not prove classic
protection or environment/runner isolation.

Top-level Action commits are frozen by the candidate, but the pinned Flutter
composite still invokes mutable `actions/cache@v5` (observed commit
`caa296126883cff596d87d8935842f9db880ef25`). The registry does not freeze this
transitive provider. Keep the source-chain/cache follow-up explicit in #386/#392;
green candidate checks do not close it. Later integration with changed application
inputs requires fresh source-bound acceptance.
