# Issue 272: roster authorization on isolated stack

Date: 2026-11-09. Status: PASS for the narrow checks below, not full issue acceptance.

The isolated API, PostgreSQL, LiveKit and built Web client ran from master
`8306413a84c224a712509d7a059916c95b00bd3c`, with synthetic accounts and
Chromium on localhost. This is a server access-control check, not a test of
Flutter PR #694 or of a physical device. The previously recorded 130-second
outage and Android candidate checks are separate evidence.

- An unauthenticated client received HTTP 401 for both participants REST and
  roster SSE endpoints.
- Two authenticated Web clients joined a voice room and a separate session of
  one account received roster snapshots with the two participants present.
- Revoking the other sessions from the active account delivered
  `session-expired` to that session's SSE listener. It received no subsequent
  snapshots during a three-second observation; both endpoints returned 401.
  The two unrevoked sessions remained usable and the roster remained at two.
- An administrator revoked the peer's voice lease; the authenticated REST
  roster changed from two participants to one.

The listener was a synthetic same-origin test page, while the two voice joins
used the actual Web UI. No private channel visibility case was tested: the
approved product brief excludes closed channels and channel ACL. This does not
prove per-channel ACL, physical-device behavior, production operation, load,
or the complete acceptance of issue 272. The isolated stack was stopped and
its temporary port modifications restored.
