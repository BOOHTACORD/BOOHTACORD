# DW-012 / GitHub #351 — Web settings hierarchy

Status: IN_PROGRESS. Final acceptance is not yet established. Epic #339 remains open.

Base: `4cda8f5c464e006f1b3d7c65c2c16395656f3bab` (master). Branch: `codex/issue351-settings-density`.

Scope: tour 03–15, Web only. Existing #295/#297 provide admin/profile lifecycle; #342 provides control styling. This change changes presentation/disclosure, not API, ACL, mutations, processing/device/LiveKit handlers or media profiles. Original private tour pixels were not available as an approved public baseline; no private account imagery is committed. Same-checkout synthetic Before captures are under `.out/issue351/before`.

## Survey and decisions

| Surface / current owner | Finding and disposition |
| --- | --- |
| Guild / `admin/guild_settings/AdminGuildSettings.vue` | Name constraints, welcome selection, revision conflict, explicit Save already useful; preserve them and the existing help disclosure. |
| Members / `admin/members/AdminMembersSection.vue` | Existing filters/results and scoped editing are functional context; retain ACL, pending and conflict flows. |
| Roles / `admin/role_permissions/AdminRolePermissions.vue` | Remove paragraph repeating the selected role. Show Refresh and default/reset action without hover. Keep deletion warning, dirty/pending state and conflict review visible. Reduce excessive table spacing; allow 200% text to wrap the header, selector and table. |
| Channels / `channel/AdminTopologyControls.vue` | Existing tree/inspector, confirmation and permission warnings remain unchanged. No mutation semantics redesign. |
| Audit / `admin/audit/AdminAuditSection.vue` | Remove header sentence repeating the audit purpose. Keep result count and loaded-page filter boundary, event details, errors and pagination. |
| Media / `admin/media/AdminMediaDiagnostics.vue` | Freshness, source limitation and empty/stale/error state are important; preserve existing diagnostics disclosure and warnings. |
| Readiness / `admin/readiness/Panel.vue` | Move health explanation and synthetic journey runner under keyboard-operable “Диагностика готовности”. Keep dependency status, capacity, age/staleness and retry visible. Preserve reserved status height across refresh. |
| Profile / `identity/ProfileSettings.vue` | Remove two descriptions repeating name/login labels. Form/result/save action follow normal document flow; explicit Save, dirty/error state and security confirmations remain. |
| Security / `identity/ProfileSettings.vue` | Keep password confirmation, logout consequence, unsaved confirmation and session revocation visible. No fictional autosave. |
| Notifications / `notification/` | Existing setting values and scopes remain; no new persistence model. |
| Audio / `voice/AudioSettings.vue` | Primary mic/speaker, local checks and activation mode remain direct. Sensitivity, shortcuts, AGC/NS/echo and processing diagnostics move under one disclosure. Device refresh and device-check help remain discoverable without hover. Processing/storage failures and clipping render outside the disclosure through `microphone_processing/Warnings.vue`. Values and callbacks are retained; native details does not unmount controls. |

An early source-only observation about a fixed audio panel height was rejected after inspecting the CSS cascade: the later production stylesheet already uses `display: contents`. No fix is claimed for that nonexistent rendered defect.

## Tests first and intermediate findings

- Added `tests/settings_density` against actual production Vue components before editing implementation. Initial baseline: 24 passed, 10 failed. The first role locator was incorrect; corrected to the existing accessible name and reran RED, which confirmed the hidden narrow dirty-state.
- Separate RED confirmed that processing failure was hidden inside the old closed diagnostic detail.
- Focused interaction coverage includes VAD/PTT assignment, processing state retained across disclosure, permission/processing errors, pending role save, retained draft after 409, role dirty/reset visibility and readiness disclosure.
- 320/390/1024/1440 at 200% root text plus separately verified actual Chromium page zoom 200% (viewport halves, DPR doubles, root remains 16px, pinch remains 1).
- Source-resolution visual review found an inherited negative audio-meter margin overlapping the device field; removed it. Additional bounds checks caught role-table min-content expansion. Further visual review caught clipped role header/selector; added a failing regression assertion before fixing wrap. These intermediate runs are not acceptance baselines.
- `.out/issue351/final-focused-v2`: 41/41 passed before the final readiness height restoration (that restoration preserves an existing accessibility contract).
- `.out/issue351/unit.log`: nearest native suite 80/80 passed. Build passed with explicit local QA public origin; known bundle/dynamic-import warnings remain.
- Traceability: PASS for all 39 committed indexed requirements; approved Windows product brief unavailable on this host. Contracts unchanged.

## Local acceptance (pending completion)

Registered under `settings` and `admin` in `tools/qa/local_features/features.json`.

Command: `DOCKER_CONTEXT=colima ./tools/qa/local_features/check.sh --feature voice --feature settings --feature admin --feature auth --feature shell --base 4cda8f5c --platform web --real-stack`.

- First intermediate check was stopped before runtime after visual defects were found.
- `.out/local-features/20261016-231804`: initial accessibility stage could not start because Vite from the interrupted check still owned 5175. The process was identified by PID/start time and removed. A separate retry then found the readiness status-height regression; reserved height was restored. Other component suites and actual runtime are being checked. This run cannot be treated as a clean all-stage PASS.
- Real API scenario `tools/qa/client_lifecycle/settings_density.mjs` opens basic/advanced audio settings, changes and restores echo cancellation, explicitly saves/restores a synthetic profile name, and returns to TEXT. During the critical media scenario it also opens/closes audio settings and verifies identical connected RTCPeerConnection objects/counts.
- Hardware capture, microphone audibility, physical screen readers and native/Flutter acceptance: NOT_RUN, outside this Web presentation leaf; no media quality or capacity claim.

## Visual observations (selected images inspected at source resolution)

Before/After audio 390/1440: primary device/mode controls and advanced disclosure are reachable, meter no longer collides with device field. Before/After profile 390: redundant captions removed and Save remains beside its result/dirty text in form flow. Before/After roles 390: deletion warning preserved; dirty text and all three actions visible; at 320/200% header and role names wrap rather than clipping. Before/After readiness 390/1440: dependencies and capacity get priority, synthetic runner remains available on request. Actual browser zoom 200% audio capture inspected; enlarged controls remain readable. Intermediate failed images are retained for diagnosis and are not approved references.

No screenshot baseline was approved to silence a difference. Final real-stack screenshots, hashes and observations remain required before completion.
