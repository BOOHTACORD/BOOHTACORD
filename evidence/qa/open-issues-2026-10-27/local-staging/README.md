# Local QA deployment on the current Windows PC

`PASS_SCOPED_LOCAL_STAGING_PREREQUISITE`, source `072426d60b1c0b1f7e5f66722a0da5faa00b50d7`.
The nine-service stack remains running under Docker project `boohtacord-local-qa`.
It uses separate local accounts, keys, storage volumes, network and PostgreSQL 17.6.
Application: <http://localhost:18088>. Grafana: <http://127.0.0.1:13000>.

| Protection | Executed command | Platform | Required before | Result |
|---|---|---|---|---|
| Owned runtime, private published ports, exact app source, real PostgreSQL and telemetry | `python -X utf8 .out/local-qa/verify_deployment.py` | This Windows PC / Docker Desktop Linux engine | Fault/load probes on this profile | [32 checks PASS](deployment-readiness.json) |
| Session contract, member ACL, missing-Origin refusal, actual TEXT delivery/deletion, two SDK peers and both UI rosters | `node .out/local-qa/smoke_final.mjs` | Installed Chrome155, two independent contexts, real local stack | Probes relying on baseline app/RTC behaviour | [6 checks PASS](browser-final-smoke.json) |
| Actual authenticated Grafana and provisioned runtime dashboard | `node .out/local-qa/smoke_grafana.mjs` | Installed Chrome155 / local Grafana13.3.0 | Using these dashboards as observed evidence | [3 checks PASS](grafana-ui.json) |

Run commands from `C:/Users/egkur/.codex/worktrees/local-qa-stack/BOOHTACORD`.
[RUNBOOK](RUNBOOK.md) contains start/stop/status commands and the local-only credentials location.
No credentials, resolved Compose configuration, cookies, tokens, SDP, private trace bodies or private logs are retained here.
Retained scripts are non-executable `.txt` copies of the actual local helpers; the private runtime files remain in `.out/local-qa`.

[Summary](summary.json), [profile receipt](profile-receipt.json), [host versions](host-runtime.json),
[dashboard source/runtime hashes](dashboard-bindings.json), [SDK stats](voice-smoke.json).
Two official image manifests were resolved directly from Docker Hub and matched the mirrored platform images:
[Caddy](library-caddy-source.json), [Grafana](grafana-grafana-source.json).

Visual review at original 1440×1000 resolution:

- [Voice workspace](connected-workspace.png): QA Voice shows two synthetic listeners, muted microphones and green connected status. Both UI rosters were asserted separately.
- [Grafana](grafana-runtime.png): the explanatory panel identifies local QA; real API/user measurements render. Missing Windows host measurements remain visibly `No data`.
- [Restored workspace](workspace.png): the owned test clients left voice; synthetic TEXT content was removed by the test.

The collector feeds real API traces to Tempo; both Grafana data sources are healthy, all native metric targets are up,
and all six dashboards are provisioned. PromQL expressions were compared with the native source and remain identical.
Local overlays bind datasource UIDs and replace the runtime text panel's production-host description with local QA scope.
The bridge permits outbound traffic; this is not an egress firewall. All published ports, including RTC, bind loopback.
The support-provider endpoint is an unreachable loopback target rather than production.

Initial attempts are retained with their original status. Early controller assumptions expected login200/Strict cookies;
the actual contract is204/Lax. LAN-advertised ICE did not connect. The canonical loopback configuration passed real
SDK connections using Chrome without extra launch flags, with normal origin-scoped local-network permission.
Repeated logins hit429 with Retry-After48; the limiter was preserved and the final run after waiting passed.
The Grafana controller was corrected to the observed `Log in` button before the final UI run.

This packet does not execute fault/load/pressure, notification delivery, alert delivery, production TLS, reboot,
Android-native local-origin, microphone, audibility or screen acceptance. No capacity profile is accepted.
Host Compose5.3.1 differs from the repository pin5.5.0; the actual Compose model and runtime passed the stated checks.
The Android production app was not retargeted and production services were not changed.

All480 source-row texts and statuses remain unchanged. Issues #240/#241/#272 remain open;
the local staging prerequisite is now available, while their remaining fault/load/platform gates require separate execution.
Earlier isolated results keep their original scope. The43 test-consolidation decisions are untouched.
