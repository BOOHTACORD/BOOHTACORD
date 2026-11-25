# Issue249 — original Windows client update acceptance

Base: `2f301dda539a9f38d5c11b477a4a946130b7e20e`, 2026-11-25.

## Qualified baseline

- Public Windows/direct/stable/x64 GET returned HTTP200, no-store/nosniff JSON,
  revision48, release `windows-direct-stable-r75`, version1.0.60/build96.
- The approved original Windows1.0.32/46 ZIP is still published. Its official
  manifest binds source `e2b19dfef3568eb00187c5dd35e244aa58ae2942` and all payload
  files; the ZIP/manifest digests are pinned in the owned acceptance tool.
- The historic client offers a manual release download page. It cannot perform
  the newer integrated Velopack update journey; that behavior is preserved.
- The current user's installation/profile/calls were not touched. Local isolated
  VM creation is unavailable without administrator rights, so runtime acceptance
  is moved to an actual disposable hosted Windows desktop.
- Actual downloaded baseline PE version is1.0.32+46; all36 manifest files match.
  Local checks execute no original client process.

## Catalog across an already completed backend deployment

The actual archived readbacks before/after the normal35f52194→2f301dda server
deployment both passed with revision48 and identical Windows policy SHA256
`e0e4748f56eec0c275dc05ea0bae57262a59d4610c7304bbbee77458d2fd8016`.
They bind their respective successful deployment/producer executions and the
same1.0.60 published manifest. ZIP bytes were downloaded and hashed independently:

- [Before, run45435182579](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/45435182579),
  artifact14940642441 SHA256 `64c25ca0d3eec78bc6db7d4a58227860c204d8259570b16bf025a7a7fffdb32f`.
- [After, run45654398047](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/45654398047),
  artifact15042456004 SHA256 `e2474b3435c90139e385e9efe5b2ece17df011cd95a4edea7f27ddbe83a9cc8d`.

This packet observed those existing operations; it did not initiate a deployment
or restart. Real-file competing/idempotent/stale promotion tests additionally
verify revision order, reopen/readback and preservation of Android/Web entries.

## Implementation and checks

- New `tools/qa/legacy_windows_update` leaf observes original released EXEs with
  external PID-scoped UI Automation and captures only their synthetic login UI.
- Verified baseline/installed file hashes, exact PE identities, live target URL
  boundaries and a genuine current per-user Setup installation are mandatory.
- The native step runs before the existing mandatory Windows recovery/GUI/SFU
  gate; source/content/workflow negative guards run in contracts.
- Focused policy tests started RED (missing implementation); wiring tests started
  RED while the actual runtime step was absent. Offline checks and C# compilation
  are local proof only, not a passing old-client UI receipt.
- PASS locally:24 nearest unit guards,8 existing catalog pytest cases, exact
  C# compilation/UTF-8 label and missing-PID checks, PowerShell syntax, full native
  contracts in an owned Linux clone, approved-spec traceability and generated
  product-map/flow checks. No application code, SDK or dependency lock changed.
- Full-contract discovery already executes the new test modules. A redundant
  proposed contracts step tripped the source-hash guard and was removed; the
  guard and automatic discovery remain unchanged. An incomplete synthetic target
  in the new concurrency test was corrected to include mandatory priority.
- Hosted old/new UI acceptance and visual review are **NOT_RUN at commit time**;
  the final outcome, source and remaining criteria are tracked on the PR/issue.

## Scope

The actual run requires the old version, current offer and details version, then
the installed current version/build and absence of a false update offer. It does
not claim authenticated settings status, migration of a real user's private
profile, Authenticode, hardware/media or a production backend restart. Catalog
promotion/revision/concurrency regression tests remain required; production is
read-only. The historical29/r52 target is not forced over a newer stable release.

Commands and safety boundaries: [owned acceptance](../../tools/qa/legacy_windows_update/README.md).

## First actual Windows run — UI PASS, overall FAIL

[CI45673955929](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/45673955929),
tested merge source `e9f0db3dc6e955bfa1ad9116965d101d9e6893e9`, retained artifact
15051099181 SHA256 `513aad41fd22d9f9c46099c08b15f1ab9a456ac86cf20f0fd6a2f65d1fc45d83`.
Actual original1.0.32/46 offer/details and installed1.0.60/96 observations passed;
manifest hashes and before/after revision48 matched. All three images were viewed
at source resolution: old offer controls and details target are visible; the
legacy summary has large underlined wrapping and the small desktop clips its
lower area. The current login/version96 fits and shows no false offer. No claim
of repairing the immutable old layout or authenticated settings is made.

The job correctly failed when TemporaryDirectory removed a still-held Windows
root after uninstall. Its early PASS JSON is rejected as whole-run acceptance.
The fix moves receipt publication after a bounded, ownership-checked root removal;
permanent locks write FAIL.29 nearest guards pass, including a real Windows
child-process CWD lock. Shipping clients, selectors and native observation logic
are unchanged; exact-head native CI and final visual review remain required.
