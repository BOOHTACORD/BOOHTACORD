# Current-state client release 1.0.55 preparation

The owner authorized Windows, Android, macOS and Web releases and server
deployment on 2026-11-14. This supersedes the earlier server-deployment hold.
The full acoustic/adaptation scope of issue 687 remains separate and incomplete;
experimental model defaults and unapproved-weight delivery guards are preserved.

The first master Build server execution on d7a1a9982 passed its source-quality
checks but failed packaging: vite.config.ts imports research_asset_guard.mjs,
which the Web Dockerfile did not copy. The new Vite build-input regression
failed on that exact missing import before the fix and passes after it. Both
local script dependencies are now copied; the production guard is retained.

The Web Docker COPY context was staged into a fresh ignored directory and built
using dependencies with the matching package-lock digest. Type checking and
Vite production compilation passed. This Windows-host context reconstruction
is not a successful Linux container build; the real master bundle remains a gate.
The local Docker client did not return a server version and was interrupted;
Docker Desktop/services were not restarted as part of this release task.

Base 099bf8636 includes the separately merged issue 786 deafen correction.
Shared Flutter version/build becomes 1.0.55+91, native release order 70; the
independent Web release order becomes 63 and version 1.0.55. iOS identity is
kept consistent with the shared manifest; no iOS release is requested.
The existing macos-v1.0.54 publication is immutable and is not replaced.
The existing profile/package-version synchronization test caught stale Dart
development defaults in CI. Updating app_version.dart to 1.0.55/91/order 70
makes that unchanged focused test pass on Windows; it is not a test waiver.

Validation: ten focused Docker-input/tag tests, three client-identity tests,
26 contract/parity regressions, OpenAPI parity (137 operations), product-map
parity and generated-map freshness passed. Publication and production runtime
are NOT_RUN here and must be verified from the subsequent workflow results.

The common version fallback has a shell parity decision in the existing feature
registry. The canonical local runner was invoked with --real-stack, all registered
features and the iOS projection on Windows. Report 20261114-230635 is BLOCKED:
1,991 Flutter tests passed/three platform skips, 872 component tests passed/one
skip; iOS runtime unavailable, source stability PASS. It is not native iOS
acceptance, and no passing real-stack/device result is claimed by that invocation.
At source resolution, the 1440x480 and 390x480 scale-2 profile captures show a
wrapped synthetic display name and content clipped at the reserved IME boundary.
Both PNGs are byte-identical to the 48d886070 acceptance capture. The version
label is not visible in those images; its actual text is covered by the focused
profile widget/package test. Other generated images were not fully reviewed,
and no new screenshot baseline or broad visual acceptance was approved.
