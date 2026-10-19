# macOS CI and patched WebRTC SDK (#400)

Fast PR contracts, native app packaging and SDK compilation are separate cost and
trust classes. `ci-contracts.yaml` always runs metadata/packaging fixtures and SDK
negative/publication tests. These do not compile the app, use an Apple runner or
claim physical media acceptance. The manual `flutter-macos` workflow runs the
same cheap checks by default; `full_build=true` additionally builds the universal
app on a disposable hosted Mac. The former unprovisioned `[self-hosted, macos]`
runner dependency has been removed. No persistent developer Mac or Keychain is
used by CI.

## Reviewed compatibility matrix

| Work | Runner | Xcode / SDK | Other inputs | Availability / evidence |
| --- | --- | --- | --- | --- |
| Fast metadata/package contracts | ubuntu-24.04 | No Apple SDK | Selected Python and Node; synthetic package fixtures | Normal PR contract gate; no native capability claim |
| Full universal macOS app | macos-26 / ARM | Xcode 26.6, build 17F113; macOS SDK 26.5 | Flutter 3.47.7 / Dart 3.13.5; existing checksum-pinned WebRTC and Sparkle | Explicit manual master build; hosted actual candidate NOT_RUN |
| SDK ARM slice + 2 native routing tests | macos-26 / arm64 | Same reviewed Xcode/SDK | recipe WebRTC/depot commits + exact routing/regression patches + GN args | Manual only; 180min job budget; actual new slice NOT_RUN |
| SDK Intel slice + 2 native routing tests | macos-26-intel / x86_64 | Same reviewed Xcode/SDK | Same recipe; x64 target and actual x86_64 Mach-O required | Manual only; 180min job budget; actual new slice NOT_RUN |
| Universal SDK assembly / ad-hoc verification | macos-26 / ARM | Same reviewed Xcode/SDK | Both exact-source/run/attempt native slices and cleanup receipts | Requires complete successful matrix; actual NOT_RUN |
| SDK publication | ubuntu-24.04 | No native compiler | Verified three-asset contract and protected production environment | Explicit master dispatch with `publish_sdk=true`; actual NOT_RUN |

Policy: `tools/ci/macos/host-v1.json`, derived from the official
[ARM image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
and [Intel image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md),
checked 2026-10-19. Image labels evolve: the job explicitly selects
`/Applications/Xcode_26.6.app/Contents/Developer` and checks actual version/build,
SDK, OS family and native architecture before costly work. An unavailable runner
or mismatched installation is BLOCKED/failure; no fallback to an unknown compiler,
self-hosted machine, cross-emulated tests or a green skipped native candidate.
The public inventory is a capability statement, not an observed BOOHTACORD run.

## Native app release behavior

The full CI app uses a fresh hosted VM, locked Flutter dependencies, the ordinary
universal builder, existing packaging checks and source-bound artifact metadata.
The successful ZIP/checksum/native manifest is retained for 30 days with
source/run/attempt in its name. Host readiness is retained even on failure.
Complete Dart/analyzer tests remain in the shared Flutter gates rather than being
repeated in every native package job. Stable `macos-release` keeps its version
and tag/master-ancestry guard, signing queue, ad-hoc verification, checksums and
immutable publication contract; it now also selects the reviewed Apple toolchain.
No Developer ID identity or Apple notarization is claimed or introduced.

## SDK recipe, source and ABI contract

The SDK workflow is dispatch-only and never a normal PR dependency. A read-only
plan job rejects existing release/tag versions before a requested publication can
consume the 180min builders. Default `publish_sdk=false` makes a candidate only.
The current r2 recipe and existing consumer pins are preserved; publishing another
SDK requires a reviewed **new immutable recipe version**, not replacement of r2.

Each build requires fresh disposable hosted execution, a clean builder source,
exact run/attempt, native hardware and an empty owned workspace. Dependency sync
is checked against the pinned WebRTC source after sync; depot self-update remains
disabled. Unsourced `--synced` reuse is refused for publishable candidates. Both
architectures execute the two actual in-memory native routing regressions; missing,
disabled, errored or failed tests cannot qualify a slice. A slice binds builder
commit, upstream/depot commits, recipe and host-policy digests, exact patch hashes,
GN/ABI arguments, real Mach-O architecture, binary/archive/test-report digests and
cleanup. Thin slices must be arm64 and x86_64 respectively; physical playback is
always a separate NOT_RUN field.

Assembly requires both receipts from the **same source/run/attempt**, exact recipe,
patch and toolchain identities, actual archive/binary/test-report checksums and
successful owned-workspace removal. Framework extraction is bounded and rejects
escaping links, overlapping symlink parents, duplicate paths and partial input.
The universal binary is checked for both architectures, packaged as a macOS
XCFramework, then ad-hoc signed and verified after final framework layout changes.
The manifest and SHA256SUMS identify the final archive. Native frameworks never
enter the repository as generated media/build output.

SwiftPM and CocoaPods keep the same current macOS archive URL/checksum. Their
source inputs, including Package.swift, are part of the reviewed native inventory.
Android/iOS retain their own locked dependencies; Web uses its own client stack.
A newly built SDK is **not** silently installed into another platform or promoted
into these consumer pins. A consumer update is a separate reviewed version/ABI
and checksum change after actual candidate acceptance. The local developer SDK
builder is separate from publishable hosted SDK evidence.

## Independent immutable publication

The publisher has only `contents: write`, only in its protected master dispatch
job, after successful assembly and immediate revalidation of source, execution,
complete native matrix, recipe, cleanup and every publication byte. It creates an
unpublished draft, uploads exactly archive/manifest/SHA256SUMS, checks the returned
asset digests/sizes and tag source, then publishes with `make_latest=false`.
Existing SDK versions are refused. Partial/failed uploads leave an unpublished
draft; inspect it before a new dispatch, never overwrite or force-move an existing
version. The publication receipt includes source, run/attempt, recipe and manifest
digests and release ID. Ad-hoc code integrity and authenticated GitHub publication
do not imply Developer ID/notarization or physical playback acceptance.

## Cleanup, timing and outstanding acceptance

Each architecture owns only its fresh `.out/webrtc` tree; cleanup verifies the
exact source/run/attempt/architecture marker and deletes that tree before its
slice can qualify. Foreign or stale workspaces are refused. Forced job timeout
may preclude a finalizer; the disposable VM is then removed and the job cannot
pass. App and assembly jobs also use disposable VMs, with no production access.
No content-addressed SDK cache has been added: reuse needs separate negative and
cold/warm measurements before approval.

Slice and assembly receipts record elapsed seconds. The two 180min SDK budgets
are separate from PR critical path and are not measured performance claims.
New hosted app, arm64/x64 SDK, assemble/publish and timing runs are NOT_RUN here,
per the owner's implementation-first instruction. Local introspection found
macOS 27.0.1 / arm64, selected Xcode 27.1 (27A9275), macOS SDK 27.0: this developer
Mac is outside the reviewed hosted policy. No compiler was switched and no SDK
build was started. #400 stays open for actual candidates and runner evidence;
#335 physical screen-audio acceptance remains separate. Evidence:
`evidence/ci/macos-sdk-2026-10-19.md`.
