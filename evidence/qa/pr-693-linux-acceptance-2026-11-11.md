# PR 693: Linux Web and native telemetry checks

- Source under test: `f8c9387e3efc8012348d68eaac16a4749f52a7e4`.
- The selected Web feature gate ran in Linux/WSL against owned disposable
  services. Unit, build, accessibility, voice UI and real-stack 1440 and 393
  stages passed; the aggregate remained BLOCKED because one screen baseline
  was skipped without isolated SFU credentials. The source stability check
  passed. No production accounts or services were used.
- That baseline was subsequently run separately with an owned loopback SFU
  and short-lived synthetic publisher/viewer credentials: one test passed
  after its 3.5-minute measurement. This does not change the aggregate report.
- A second gate run supplied an owned SFU from the start: all 19 screen-profile
  tests passed. One conversation action test failed while Vite loaded a module;
  its isolated retry passed without code changes. The full run must retain FAIL;
  the cause of the intermittent module-load failure is not established.
- The native Flutter telemetry test passed separately against an isolated
  Collector, relay and Tempo. Its temporary containers, network and volume
  were removed. Two macOS-only Flutter tests and iOS acceptance remain NOT_RUN.
- Visual review at source resolution covered two of 672 generated screenshots:
  the reconnecting status, participant cards and cancel action were visible
  at desktop and narrow mobile widths. Remaining screenshots were not reviewed.
  Desktop SHA-256: `f5ed4f07708cf0703b04ed88c9d616a70973b6269861ec03e35f396879cdd582`.
  Mobile SHA-256: `d1af61001f6bd1378c64460b5a7a645fc4091371569f65948018abd9deb7e727`.
- Physical-device, audible-media, production and full platform acceptance
  remain NOT_RUN. This is not evidence that the reported Android ICE issue is fixed.
