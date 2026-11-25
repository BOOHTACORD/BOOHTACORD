# Production smoke evidence — 2026-11-25

- Current production source when tested: `a07ecade51655fe5ffceda006d7f326a0503c932`.
- Local Chrome against live production: PASS for public health, exact source,
  ordinary-member login, empty dedicated voice channel, connected WebRTC peers,
  synthetic audio publication, disconnect, logout and unchanged source.
- `production` environment: required reviewer configured and read back; the
  previous custom branch restriction remains enabled. It is also used by the
  server bundle signer, so signing and installation each require approval.
- `production-smoke` environment: separate test identity secrets, custom branch
  restriction to `master`; no production transport or signing credentials.
- Automated GitHub-hosted post-install job: NOT_RUN until this change is merged
  and a later release is approved. Local success does not prove hosted CI.
- Two-party audio, physical microphone capture, native clients and devices:
  NOT_RUN. No rollback or simulated production fault was attempted.
- The previous delivery-network check selected an October producer whose
  retained artifact had expired. Bounded discovery independently selected the
  successful retained `a07ecade51655fe5ffceda006d7f326a0503c932` producer and
  passed shipping authority verification; its hosted full download is NOT_RUN
  until the updated acceptance workflow completes.
