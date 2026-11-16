# Issue #787 — Flutter macOS → Web sender telemetry pairing

## Result

The physical macOS Flutter sender and authenticated production Web viewer completed a paired run in the same isolated API/SFU stack. The Web viewer joined `QaVoice`, selected the native screen publication, decoded video, received a scoped `screen_telemetry.updated` event, and showed a fresh sender sample separately from the configured target.

- Native Flutter focused suite and physical macOS Debug build: **PASS**. The build used source base `1a15f8c3b15f2d2f629e095dfbfa1a6eec799732`; no Flutter product source changed in this QA follow-up.
- Native healthy sender case 18: **PASS**, physical macOS. The actual capture readback showed **1280 × 720**; **60 FPS** was identified as configured.
- Authenticated Web viewer receipt `receiver-18.json`: **PASS**. Voice connected, selected stream decoded, one scoped native telemetry event received, fresh sender sample visible, and configured target labeled separately.
- Source-resolution screenshot `receiver-18-web-pair.png`: **1440 × 900**. Review found the selected video and statistics panel within the viewer; receiver values, measured sender resolution, configured capture FPS, and `Цель: 1080p · 60 FPS` are legible and distinct.
- Focused QA policy tests: **7/7 PASS**. Owned Keychain cleanup case 0: **PASS**. Runner disposal: `phase=disposed`, `owned_resources_removed=true`.

The screenshot and runtime receipts remain under ignored `.out/qa787-20261116/`; they are not committed. Earlier retries exposed two QA-observer defects (an unrecorded scope boolean and a click on hidden viewer controls). The corrected observer and explicit user-like hover passed in case 18; the failed retry receipts remain local and are not counted as product failures.

## Limits and remaining gates

This is one same-host, 110-second paired flow with a synthetic native QA window and a headless browser. The browser explicitly ignored the local test certificate error; this does not test browser trust-chain acceptance. It does not establish the five-minute/two-physical-device presentation gate, native capture-picker acceptance, audio fidelity, hardware/network media quality, or capacity.

- Flutter macOS → Web selected-stream telemetry flow: **PASS**.
- Flutter Android/iOS/Windows → Web pairing: **NOT_RUN**.
- Native/system capture-picker acceptance: **NOT_RUN**.
- Hardware media-quality and load/capacity evidence: **NOT_RUN**.

Issue #787 remains open until the remaining platform and release acceptance gates have evidence. No media-quality or capacity claim is made.
