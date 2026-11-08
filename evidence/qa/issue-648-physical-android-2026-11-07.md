# Android voice recovery: isolated physical checks, 2026-11-07

- Candidate source: `d2df1c1c3319389ff2f7f10766abf3ba49f5a043` (PR #669).
- Physical client: Samsung SM-A576B, Android 16, debug build with the
  test-only application ID suffix `.qa648`. The installed production client
  and its session were retained. The test build used an instrumentation
  entrypoint and a pinned certificate for the disposable loopback server.
- Environment: isolated Docker API, PostgreSQL and LiveKit, synthetic accounts,
  Android USB reverse for loopback TLS and media TCP. Both clients joined in
  listener mode; audio capture, playback and RTP quality were **NOT_RUN**.

## Simultaneous API and LiveKit interruption

| Outage | Physical Android | Independent Android emulator |
| --- | --- | --- |
| 133 seconds | PASS: reconnecting, then listener in original channel | NOT_RUN |
| 311 seconds | PASS: reconnecting, then listener in original channel | PASS_SCOPED: returned to listener; simultaneous peer visibility not retained |
| 913 seconds | PASS: reconnecting, then listener in original channel | PASS: returned to listener and observed a remote participant in the channel |

The 15-minute observer screenshot showed two channel participants. The same
screen displayed a transient `Состав недоступен` warning immediately after
recovery. This observation is not proof of audible media or production health.
Observer screenshot SHA-256:
`6aaa5d624ec17be2727659c6d94c05a49835105b01a46ea3ef2c0e5030e290a1`.

## Physical network loss

- Wi-Fi and mobile data were disabled for 131 seconds; Android reported
  `Active default network: none`. The voice controller entered reconnecting
  and returned to the original channel after both networks were restored.
- In a second 44-second outage, the test pumped frames throughout the outage.
  Accessibility inspection showed `Голос восстанавливается`; after network
  restoration the controller returned to listener in the same channel.
- The USB loopback reverse remained available for the owned test server, so
  this is a connectivity-notification and client-state test, not a claim about
  production network transport. The original network settings were restored.
  The current isolated debug APK SHA-256 is
  `580207d5b4006c93df7237986607aaa1494b92e12eaffc5f6b652865ea4845c8`.

## Remaining acceptance

The separate API-only and LiveKit-only cases, measured new credentials,
explicit leave during outage, handoff/ACL revocation, audible media, physical
Windows/macOS/iOS and production smoke remain **NOT_RUN**. This evidence does
not close issue #648 or establish production deployment. The earlier 5-minute
observer run ended after the phone test exited and cannot establish simultaneous
peer visibility; the 15-minute run explicitly kept the phone connected.
