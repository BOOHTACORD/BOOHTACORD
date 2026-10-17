# DW-012 / GitHub #351 — Web settings hierarchy

Status: PASS for #351 implementation, full registered Web integration checks and targeted visual review. GitHub #351 remains open pending publication/review. Epic #339 remains open.

Before base: `4cda8f5c464e006f1b3d7c65c2c16395656f3bab`. Integrated master: `1784d2cd` (#347/#361). Final implementation: `9e0a4b81582f320a3d8f5f3d609c4cfbb1ce4afa`. Branch: `codex/issue351-settings-density`.

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

## Local acceptance

Registered under `settings` and `admin` in `tools/qa/local_features/features.json`.

Command: `DOCKER_CONTEXT=colima ./tools/qa/local_features/check.sh --feature voice --feature settings --feature admin --feature auth --feature shell --base 1784d2cd --platform web --real-stack`.

- First intermediate check was stopped before runtime after visual defects were found.
- `.out/local-features/20261016-231804`: initial accessibility stage could not start because Vite from the interrupted check still owned 5175. The process was identified by PID/start time and removed. A separate retry then found the readiness status-height regression; reserved height was restored. This run cannot be treated as a clean all-stage PASS.
- Real API scenario `tools/qa/client_lifecycle/settings_density.mjs` opens basic/advanced audio settings, changes and restores echo cancellation, explicitly saves/restores a synthetic profile name, and returns to TEXT. During the critical media scenario it also opens/closes audio settings and verifies identical connected RTCPeerConnection objects/counts.
- `.out/local-features/20261017-105144/report.json`: all 15 registered stages PASS at source `9e0a4b81582f320a3d8f5f3d609c4cfbb1ce4afa`; report retains `REVIEW_REQUIRED` because it includes screenshot sets for several adjacent features. Web unit 1555/1555, build PASS, accessibility 110/110, settings density 41/41, voice interface 24/24, and real-stack authenticated journeys PASS at 1440px and 393px. The run cleaned its owned resources.
- The real-stack settings scenario saved/restored a synthetic profile name and processing toggle. The active-voice scenario opened and closed audio settings while two listeners were connected, then verified the same connected RTCPeerConnection objects/count. Captures for audio settings and active voice were visually reviewed at source resolution at both widths.
- Hardware capture, microphone audibility, physical screen readers and native/Flutter acceptance: NOT_RUN, outside this Web presentation leaf; no media quality or capacity claim.

## Visual observations (selected images inspected at source resolution)


All 33 component Before images and all 76 final settings-density After images were inspected individually at source resolution. The final integrated run reproduced the same 76 paths: 70 PNG hashes match the previously reviewed focused run; the remaining 6 were reviewed individually (390px 200% audio wrapping, advanced audio state, and time-varying media freshness). Across 390/1024/1440, channel/topology controls and notification scopes remain intact; audit/profile descriptions are shorter; role warning, dirty/pending text and actions remain visible; readiness keeps dependency/capacity status in view while its synthetic runner is disclosed; audio primary controls stay direct and advanced controls open on request. At 320/390 with 200% text the VAD/PTT choices wrap within their card, with vertical scrolling and no horizontal overflow. Active-voice 1440/393 captures show the connected voice dock while audio settings are open.

No screenshot baseline was approved. The final real-stack screenshots and hashes are retained in `.out/local-features/20261017-105144`; their reviewed #351 frames are summarized above.

## Integration checkpoint

`.out/local-features/20261016-232331`: all 14 stages PASS, 1552 Web unit tests, 41 focused settings scenarios, 110 accessibility scenarios, two actual API/SFU listener journeys at 1440/393. Reports confirm explicit synthetic profile save/restore, processing toggle/restore, return to TEXT and identical connected peer objects/counts through audio-settings navigation. Owned resources removed. This was the pre-#347 integration checkpoint; a final warning-word wrap was then independently tested and visually inspected. It is not substituted for the final merged-source run.

The prior 507 was traced to actual readiness showing a 979.3 MiB default attachment tmpfs against the unchanged 2048 MiB server reserve. QA now specifies a sparse 4 GiB ceiling on its owned ephemeral attachment tmpfs; actual fixture data is tiny, container memory cap/permissions/ownership remain unchanged, and production storage admission is untouched. Updated harness test was RED before the fix; 20 native harness tests passed afterward. No images, volumes or unrelated files were deleted.

Traceability verifier PASS: 39 indexed requirements referenced; the approved Windows product brief remains unavailable on this host. Contracts are unchanged.

Complete component review of `.out/local-features/20261016-233114/web-settings_density`: 76 PNG files, 64 byte-distinct images, individually inspected at source resolution (byte-identical duplicates share the same visual result). The only additional defect found was VAD/PTT min-content overflow inside its card at 320/200% text. Added RED assertion for card scrollWidth, allowed rem-based segment wrapping, then reran all 41 scenarios PASS and inspected 320/390 enlarged and 390 normal audio captures. The final merged-source run above confirms the fix in the complete registered suite. No screenshot baseline was approved. The generated broad report remains `REVIEW_REQUIRED`; only the #351 settings-related images received targeted manual review in this evidence record, and no claim is made about uninspected images belonging to adjacent features.
