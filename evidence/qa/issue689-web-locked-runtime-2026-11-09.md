# Issue 689: Web real stack after delivery locking

- PASS: the 393 CSS-pixel critical lifecycle run against disposable local
  Go/PostgreSQL/LiveKit/Caddy/Tempo services completed with owned cleanup:
  `.out/issue689-mobile-locked/393/report.json`. It includes voice and screen
  lifecycle, application-socket failure while voice stays connected, roster
  recovery and the log-composer viewport assertion.
- Source was HEAD `72928320d` plus uncommitted changes. The test uses synthetic
  accounts and browser-generated media; it is not an immutable release build,
  physical media-quality evidence or a full performance/security matrix.
- VISUAL (partial): the connected-voice and chat-fault/media-connected images
  were viewed at original resolution. Two listener cards, voice status and
  controls are legible; the recovery image has the navigation list scrolled and
  a channel row partly above its visible area. The remaining 68 images have not
  been reviewed; previous images do not substitute for this later build.
