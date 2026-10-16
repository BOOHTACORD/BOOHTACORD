# ADR-027: policy-selected, publisher-signed desktop updates

Date: 2026-10-14. Status: accepted for implementation; release acceptance pending #337.

The existing UpdateController remains the only compatibility checker. Its target
may optionally carry a versioned `install_artifact` envelope. Older clients keep
`action=open_download_page`. Installing clients authenticate the exact payload
with an embedded Ed25519 publisher key before trusting artifact URLs or identity.
A deployment's administrator is not a software publisher. No key received from a
server becomes a client trust root. Rotation requires a previously trusted client
release or explicit replacement installation; silent TOFU is forbidden.

Use Sparkle 2.10.0 on macOS and Velopack native C API 1.2.161 on Windows. Native
integration must select the single frozen policy target, disable autonomous
selection/auto-apply, and keep helper invocation behind explicit restart consent.
The initial updater-capable release is installed manually once. Existing portable
Windows users get an explicit per-user installation migration, never a claimed
in-place Velopack upgrade of an arbitrary ZIP. macOS sandbox remains enabled;
Sparkle's documented sandbox/XPC integration is required. Unsupported installation
locations fail safely with actionable instructions. Neither Gatekeeper nor TLS
validation is disabled. Ad-hoc OS signing is not publisher authentication.

Sparkle 2.10 rejects file-URL feeds and enclosures. At consented apply only,
a short-lived random-path HTTP transport bound exclusively to 127.0.0.1 supplies
the single verified local archive and generated one-item feed. It is local IPC,
not a network download source. Sparkle verifies the publisher EdDSA archive again.
Remote downloads remain HTTPS with ordinary certificate validation. No global
ATS or TLS exceptions are introduced.

The signed payload binds application/package, release ID/order/version/build,
platform/architecture/distribution/channel, package type, immutable download URL,
size/SHA-256, native signature/feed metadata and minimum OS/API/updater versions.
Download uses a separate credential-free transport with bounded redirects to
GitHub's actual asset hosts. Verify archive trust before any extraction. A ready
package is not an installed release. Sleep/offline/cancellation cannot claim success.

User data lives outside replaced binaries. Immediately before consented restart,
flush an origin/account-scoped, versioned local checkpoint and persistent drafts.
Do not store credentials in checkpoints, command lines or diagnostics. Reload ACLs
before applying routes. Never replay sends/uploads or silently resume screen share.
A new release acknowledges its actual package identity after local bootstrap;
backend reachability is independent. Native installation and recovery require a
bounded journal/rollback and genuine N -> N+1 tests on both operating systems.
Until those pass, native capability remains fail-closed and the issue remains open.

Publisher private key: owner-managed, outside checkout, user-only permissions.
Only `clients/flutter/assets/updates/publisher.pub` is committed. Build/promotion
must reject missing signatures and unpublished artifacts rather than enabling a
server-supplied installer. No production catalog is promoted by this ADR.

Primary references:
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/sandboxing/
- https://docs.velopack.io/getting-started/cpp
- https://docs.velopack.io/integrating/overview
