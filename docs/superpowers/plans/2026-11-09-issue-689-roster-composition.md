# Issue 689: application roster composition

**Route:** application route composition and `app/voice_realtime` integration.

- [x] Exercise shared coordinator, per-socket guard and real WebSocket handler together, including shutdown.
- [x] Reuse the existing LiveKit gate, roster repository and signed-webhook notifier; own the coordinator via application lifecycle and register the capability on the existing authenticated route.
- [x] Run focused Go tests, composed Linux route tests, race tests and native build. Real-stack PostgreSQL/LiveKit and full issue gates remain separate.
