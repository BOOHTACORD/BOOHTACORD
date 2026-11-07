# Private join-sound processor

The API exposes authenticated `GET/POST/PATCH/DELETE /api/v1/me/join-sound` and
`GET /api/v1/voice/join-sounds/{id}`. Management requires the account fence header;
mutations retain the deployment's exact-Origin policy. Upload the raw file body.
A successful upload is initially disabled. Enable it explicitly with
`PATCH {"enabled":true}`; DELETE invalidates the previous ID. Downloads use
`no-store`; room/session ACL is checked for each request.

Build `backend/Dockerfile.join-sound-worker` and run the container smoke target:
`bash tools/qa/join_sounds/container_smoke.sh <worker-image>`.
Set `JOIN_SOUND_PROCESSOR_IMAGE` to the verified image digest and add this Compose
overlay to the normal deployment. It gives the worker a dedicated internal network,
no published ports or credentials, UID 65532, read-only root, a bounded tmpfs,
256 MiB memory, one CPU and 64 PIDs. Only the API shares this worker network.

Without the overlay/processor URL, upload returns 503 while voice remains available.
Removing the overlay disables new processing; stored audio remains protected by
the API ACL. The normal signed server bundle does not yet include this worker
image or activate the overlay. Integrate its verified artifact into delivery before
enabling the production feature; this document is not a deployment receipt.

Client upload UI, shared playback and event metadata are still under development.
