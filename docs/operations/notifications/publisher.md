# Publisher relay and native release

Owner: the official application publisher provisions the relay domain/TLS, private PostgreSQL, FCM project and Apple credentials. A guild operator only approves the official relay and installation signing key. No publisher secret belongs in a guild image, client build or repository.

Build `backend/Dockerfile.push-relay` separately. Use an immutable image digest with the opt-in `deploy/notifications/compose.relay.yaml` profile `publisher-push`; it is deliberately absent from the normal guild composition. Terminate public HTTPS on the approved domain and expose only port8093 through the gateway. Keep PostgreSQL and9097 metrics private. Do not forward arbitrary tenant trace context into trusted telemetry.

Use separate staging/production databases and domains. `RELAY_NAMESPACE` binds a database permanently; a mismatched namespace fails startup. `RELAY_ENABLED`, `RELAY_ANDROID_ENABLED`, and `RELAY_IOS_ENABLED` default false. A platform disabled at startup quarantines its pending jobs and rejects new sends. Missing credentials leave core health available with `provider_available=false`; enrollment/send returns503. Independent device/grant revoke remains available.

Provision these outside the checkout and database:

- `RELAY_SECRET_KEY_FILE`: independently generated32-byte encryption key, base64 encoded.
- `RELAY_SIGNING_KEY_FILE`: independently generated32-byte Ed25519 seed, base64 encoded. Publish only its public key to official builds and approving guilds.
- `RELAY_FCM_SERVICE_ACCOUNT_FILE`: bounded service-account JSON for the exact `RELAY_FCM_PROJECT`, least privilege permission for FCM sends. No Firebase Auth or Analytics is required.

The adapter fixes OAuth and FCM destinations, disables ambient proxies/redirects and limits each call. Audit IAM and service-account expiration/revocation in the publisher project. Set no dummy production keys to make a health check green.

Official mobile builds must explicitly set `NOTIFICATION_ANDROID_ENABLED=true` or `NOTIFICATION_IOS_ENABLED=true` using Dart defines, plus `NOTIFICATION_NAMESPACE`, `NOTIFICATION_RELAY_ORIGIN`, `NOTIFICATION_RELAY_PUBLIC_KEY`, `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, and `FIREBASE_PROJECT_ID`. These client options identify the publisher app; the service-account private key and APNs signing material stay with the publisher. Empty configuration is valid for chat/voice and makes remote delivery unavailable. Desktop never initializes the mobile push driver.

Android requires GMS, the correct package `ru.boohtacord.app`, publisher Firebase registration and Android13+ OS permission where applicable. The driver checks GMS locally, uses the separate `boohtacord_remote_v1` channel and preserves voice/screen notifications. The pinned Firebase Messaging17 API registers an FID; relay `fcm_fid` maps to HTTPv1 `fid` and is distinct from a legacy `fcm_token`/`token`. Do not relabel one as the other.

iOS requires macOS/Xcode, the publisher Apple team, push capability/provisioning, Firebase APNs credentials and a signed `ru.boohtacord.app` build. The target remains iOS15+. Debug uses `NOTIFICATION_APNS_ENVIRONMENT=development`; Release uses production. Provisional/denied/APNs-not-ready states are separate. ReplayKit groups and audio/background behavior remain in the existing project. No PushKit, content extension, fabricated badge or second local OS presenter is added.

Enrollment is explicit: the app receives a neutral provider challenge, proves possession with its physical Ed25519 key, approves a specific server origin/installation public key, verifies the relay-signed receipt, then activates the own-session backend binding. A relay202 and a provider message ID do not prove an OS alert. Foreground handlers do not create another system card.

Rotation/recovery procedure:

1. Kill sending on the affected relay and guild with `push-relay --kill` and `notification-control --kill`. Provider-accepted alerts cannot be recalled.
2. Revoke affected grants/bindings through the owning device/account before retiring reachable credentials. Offline revocation remains queued and blocks re-enrollment in that publisher scope until reconciled.
3. VAPID or app target changes require an explicit device refresh. Replacing an encryption key makes its existing ciphertext unusable; keep sending disabled until affected bindings are revoked and enrolled again.
4. Installation public-key pins are immutable. A new installation signing key must not overwrite the old pin. Migrate through a newly approved trusted relay endpoint/deployment, retain the old revoked namespace isolated, and require explicit device approval. A changed receipt-signing key requires an updated pinned official client and guild configuration.
5. A lost physical device key cannot authorize the old route. Revoke through another authorized account session; retire the previous app installation/FID before approving a fresh installation. Do not silently claim an active address with a new key.
6. Revoke retired IAM/APNs credentials with the publisher, then allow only new jobs with `--resume`. Test with synthetic staging accounts before rollout.

Queue limits:10000 pending jobs,100000 retained jobs,1000 immutable tenant pins,20 active grants per physical app,1000 active grants per tenant,6 attempts, original event TTL at most1hour (also clipped to grant/device expiry). Terminal job metadata is removed after expiry+1day in bounded batches. Device/grant tombstones remain until their dependent jobs and validity horizon permit removal. Pin capacity intentionally requires publisher intervention; no automatic trust eviction occurs. These are engineering bounds, not measured delivery capacity or an SLA.

Never roll a database back to a state that reactivates revoked grants. Compatible application rollback retains additive schemas and persistent kill policy. This repository explicitly forbids backup/snapshot jobs; this change introduces none. Key recovery and storage protection remain publisher-owned prerequisites, not a claimed recovery test.

Investigate `docker/observability/dashboards/notifications.json` and `notification-alerts.yaml`. Initial alerts require volume denominators and preserve unknown/no-data. Optional relay Prometheus scrape uses its private address and trusted static labels. Device IDs, references, endpoints, tokens, message text and names are excluded from labels/spans/logs. Opened is authenticated tap handling; read is the existing server read cursor. Display remains unknown without device evidence.

Force-stop Android, force-quit iOS, network/OS scheduling, OS channel switches and browser limits can prevent delivery. Do not promise a deterministic background latency. Safari iOS Home Screen Web Push is a separate acceptance row.

Local source, real-PG, mock-provider, browser and build checks are recorded separately from real provider/device delivery. The owner requested local checks only: real FCM/APNs/Web provider delivery, physical Android/iPhone, Apple signing and iOS Home Screen/Safari remain NOT_RUN. They cannot close epic554/release gate564.

References: [FCM HTTPv1 Message](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages), [message lifespan](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan), [Apple remote notifications](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns).
