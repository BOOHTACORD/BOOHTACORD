# Private join-sound processor

The API exposes authenticated `GET/POST/PATCH/DELETE /api/v1/me/join-sound` and
`GET /api/v1/voice/join-sounds/{id}`. Management requires the account fence header;
mutations retain the deployment's exact-Origin policy. Upload the raw file body.
A successful upload is initially disabled. Enable it explicitly with
`PATCH {"enabled":true}`; DELETE invalidates the previous ID. Downloads use
`no-store`; room/session ACL is checked for each request.

Build `backend/Dockerfile.join-sound-worker` and run the container smoke target:
`bash tools/qa/join_sounds/container_smoke.sh <worker-image>`.
The signed server builder includes the worker OCI archive with source labels,
SBOM/provenance and the signed manifest. The installer imports its verified digest,
sets `JOIN_SOUND_PROCESSOR_IMAGE`, and selects this overlay during normal rollout
and readback. Legacy two-image signed releases remain readable. The overlay gives
the worker a dedicated internal network,
no published ports or credentials, UID 65532, read-only root, a bounded tmpfs,
256 MiB memory, one CPU and 64 PIDs. Only the API shares this worker network.

Without the overlay/processor URL, upload returns 503 while voice remains available.
For a configuration rollback, set `JOIN_SOUND_PROCESSOR_URL=` explicitly in the
host environment and recreate the API through the guarded deployment procedure.
The empty value disables new processing; stored audio remains protected by the
API ACL. It does not alter voice transport, preferences or existing user data.
Do not roll back applied migrations by replacing an incompatible backend. This
document is not a deployment receipt.

Web and Flutter profile panels manage upload, enable, preview and deletion. The
listener's master/deafen, per-event switches, custom acceptance and volume govern
local playback. Tokens contain only the enabled resource identifier/revision;
downloads still require an active same-room session, or the owner's preview.
