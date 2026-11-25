# Deployment configuration

`compose.yaml` is the production entrypoint. It includes operator commands and
LiveKit configuration and contains no build instructions. `compose.dev.yaml`
adds the API/web source build for development. The root Compose file forwards
to this configuration during migration.

The API trusts forwarded client addresses only from `TRUSTED_PROXY_CIDRS`.
Production Compose gives Caddy the fixed `PRIVATE_PROXY_IP` on the private
network and defaults trust to that single address. If the private subnet or
proxy address conflicts with the host network, change `PRIVATE_NETWORK_SUBNET`,
`PRIVATE_PROXY_IP`, and `TRUSTED_PROXY_CIDRS` together. Keep the API attached
only to the internal network; do not publish its port.

From the repository root, validate without contacting a Docker daemon:

```sh
docker compose --env-file .env.example -f deploy/compose.yaml --profile operator config --quiet
python3 -m tools.verify.compose_layout.check
```

Build a development installation with a privately provisioned `.env`:

```sh
docker compose --env-file .env -f deploy/compose.yaml -f deploy/compose.dev.yaml up --build -d
```

Production uses `python3 -m tools.release.install.run` with a signed release
bundle. The installer selects the retained release's exact Compose file and
passes its environment file explicitly, independently of the working directory.
It imports verified images and never invokes the development overlay.

After installation, the separate [production smoke journey](../tools/qa/production_smoke/README.md)
checks the installed source, login and voice connection. Production release jobs
require approval in the GitHub `production` environment. A failed smoke job
does not automatically roll back the installed release.

The project is still `voice-platform`. Services, operator commands, migration
dependencies, published ports and networks retain their identities. Existing
`postgres-data`, `attachments-data`, `caddy-data`, and `caddy-config` volumes
are reused. Configuration files moved to `caddy/` and `livekit/`; migrations
remain embedded in the Go application. Observability infrastructure is separate.

Client update policy is mounted read-only from `client-updates/catalog.json`.
Validate it before a rollout with `python3 -m tools.release.client_updates.catalog
validate --path deploy/client-updates/catalog.json`. Native selectors stay
`unconfigured` until the matching GitHub release URL is live.
