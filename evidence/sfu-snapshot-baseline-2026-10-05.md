# Real SFU snapshot fan-out baseline

Date: 2026-10-05; executor: GitHub Ubuntu 24.04 owned QA fixture.
Issue: #81; measurement before enabling any snapshot cache.
Source merge: `206414ab23296ee4191d32d5c707301654cb16ba`.
Head: `89390adffe6f8aff29161f8e3dc3fb76c45855a1`.
[Actual run](https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/37354499156): PASS.

| Virtual authenticated HTTP observers | RoomService calls | Calls/sec | HTTP p95 ms |
|---|---|---|---|
| 1 | 1 | 147.423 | 6.395 |
| 20 | 20 | 371.351 | 39.482 |
| 100 | 100 | 512.397 | 51.741 |

Requests use the actual secure-cookie Go endpoint and real PostgreSQL/LiveKit.
The fixture has one visible VOICE channel and an absent SFU room; ListRooms
is therefore the real fan-out measured here. Observers share one authorized
session; this is HTTP fan-out evidence, not 100 WebRTC publishers or a media
capacity profile. Every response is checked for `Cache-Control: no-store`.

Raw receipt: `critical-next-five-issues/sfu-baseline/report.json` in local QA artifacts.
API binary SHA-256: `4bb41bff22da9e5ee712cc0b51f8e4d45c6eb66409a60cf5efaabb6d9480f077`.
Owned resources were removed. No production volume or data was touched.

Measured fan-out justifies one retained metadata scope, single-flight and a
250 ms TTL. Each response must still authenticate and repeat database
account/lease visibility checks. Expired SFU failure has no stale success fallback.
Follow-up bounded measurement and revoke/block tests must identify their source.
