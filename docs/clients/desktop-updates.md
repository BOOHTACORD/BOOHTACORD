# Desktop update delivery (#337)

The first client containing ADR-027's embedded publisher root must be installed
manually. Existing ZIP builds cannot acquire an updater through their old
open-download-page button. Windows users run the per-user Setup once; macOS users
move the app into `/Applications` or their own `~/Applications`. Unsupported
locations fail safely and provide the official releases page.

Build with the shared native identity using `python -m tools.build.macos.run` or
`python -m tools.build.windows.run`. These restore hash-pinned official SDKs.
macOS additionally compiles and embeds the fixed-purpose recovery monitor;
`tools/build/macos/package.sh` seals/verifies the entire app and creates the ZIP.
Windows produces both the ordinary directory and Velopack Setup/full NUPKG in
`.out/releases/windows`. The SDKs and build outputs are never committed.

The owner-held Ed25519 private key is outside the checkout, at
`~/.config/boohtacord/desktop-updates/publisher-ed25519.pem` on the release Mac.
Do not put its contents in source, logs, chat, artifacts or workflow configuration.
The public root is `clients/flutter/assets/updates/publisher.pub`; macOS
`SUPublicEDKey` must match it. Apple distribution `.p12` is separate.

Create a payload following `contracts/desktop-update-artifact.schema.json`, using
only the exact newly built package identity. Run
`python -m tools.release.desktop_updates.sign --help` for signing arguments.
Use OpenSSL 3 with Ed25519 support. The signer fills size/SHA-256 and the Sparkle
archive signature; it signs the exact metadata bytes with a domain separator.
The private key is never shipped to a self-hosted deployment.

Publish the immutable package asset before promotion. Obtain the real GitHub
release JSON including its uploaded asset digest. Run
`python -m tools.release.desktop_updates.promote --help` to create a compare-and-
swap catalog candidate. Promotion authenticates metadata and the local package,
requires the exact published tag/URL/size/SHA-256, and rejects draft/prerelease or
unverifiable assets. Keep independent Windows/macOS selectors; a universal Mac
archive may support both arm64 and x64, promoted separately. Never choose
`releases/latest` as an installer source. Deploy backend support before serving
the new optional envelope. Legacy actions remain in the target for older clients.

Download, verification, extraction and baseline retention happen before Ready.
No installer or recovery process starts on Download, Later, focus or a timer.
Restart explicitly confirms interrupted calls/shares/uploads, flushes encrypted
origin/account-scoped state, and bounds media/WS shutdown. Only then does the
native installer run. Sparkle receives the one selected local archive through a
random-path loopback feed and verifies its EdDSA signature again; Velopack receives
a one-item local feed with automatic startup application disabled.

The compiled recovery monitor runs outside replaced binaries, waits for the
specific old process to exit, and accepts a transaction/build/release bootstrap
receipt from the actual new client. It registers a one-shot user recovery job
only during consented apply. Server availability is not the bootstrap condition.
A failed bootstrap attempts the immediately previous local version once. It
never force-kills a still-running client or overwrites an unrelated installation;
permission/locking failures preserve the baseline and report manual recovery.
Workspace data and secure-session storage remain outside binary directories.
Sends/uploads are never replayed and voice/screens are never secretly resumed.

Acceptance is tracked in
`evidence/release/issue-337-desktop-updates-2026-10-14.md`. Both genuine installed
N → N+1 and rollback scenarios must pass before #337 is closed or the production
catalog is promoted. Compilation/unit tests alone do not meet that gate.
