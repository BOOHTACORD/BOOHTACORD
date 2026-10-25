# Operator notification runbook

## Disabled by default
Notifications are off unless an operator explicitly configures them. Missing keys, invalid namespace, or unavailable provider keep chat/voice usable while notification delivery remains unavailable.

Namespace must be exactly `staging` or `production`. Each namespace uses a separate database and immutable pin. Do not mix staging and production data.

## Keys and secrets
- Each key is32 independent random bytes encoded as base64 text in an operator-owned file outside the database.
- Never print, log, or commit key material.
- Key files referenced by configuration:
  - `NOTIFICATION_SECRET_KEY_FILE`
  - `NOTIFICATION_SIGNING_KEY_FILE`
  - `NOTIFICATION_VAPID_PRIVATE_KEY_FILE`
- VAPID public key and contact are plaintext configuration values: `NOTIFICATION_VAPID_PUBLIC_KEY`, `NOTIFICATION_VAPID_CONTACT`.
- Relay keys:
  - `RELAY_SECRET_KEY_FILE`
  - `RELAY_SIGNING_KEY_FILE`
  - `RELAY_FCM_SERVICE_ACCOUNT_FILE`

## Trusted origin and installation
- Web delivery is bound to the trusted origin/installation identity. Binding scope includes trusted origin, account, issuing session, device instance, provider namespace, and generation.
- Device consent for the current session is required before addressed deliveries are accepted.
- Revocation stops new sends. Already-accepted neutral provider alerts cannot always be recalled.

## Web push constraints
- Exact allowhosts list: `NOTIFICATION_WEB_PUSH_HOSTS`.
- HTTPS public-only endpoints; no proxy, no redirect, private/metadata addresses rejected.
- No environment proxy inheritance.

## Publisher relay
- The publisher relay is a separate trusted opt-in service. It is not bundled with guild images or other backend features.
- Relay address: `RELAY_ADDRESS` (default 127.0.0.1:8093).
- Relay metrics: `RELAY_METRICS_ADDRESS` (default 127.0.0.1:9097).
- Relay enabled only when `RELAY_ENABLED=true`.

## No production calls
Do not execute real provider sends during local testing or unit tests. Physical delivery is NOT_RUN unless explicitly authorized in staging/production with proper credentials.

## Kill switch and resume
- Notification control: `notification-control --kill` / `--resume` using `DATABASE_URL`.
- Relay control: `push-relay --kill` / `--resume` using `RELAY_DATABASE_URL`.
- Kill prevents new sends and quarantines pending work. Resume allows new sending but does not replay expired or quarantined history.

## Operational bounds
- Grace period: 5s.
- External TTL: 1h.
- Sound window: 60s.
- Attention window: 30s.
- Max retries: 6.
- Pending intents / deliveries / relay jobs: 10000 each.
- Relay retained jobs: 100000.
- Terminal job metadata retention: expires_at + 1 day. Revoked profile tombstones remain while their issuing session is live to fence late registration. Immutable tenant signing pins remain retained; capacity is finite.

## Unknown delivery
Unknown delivery outcomes are not retried blindly. Ambiguous timeout remains `delivery_unknown`. Acceptance is not delivery.

## Preference changes
Account opt-in, type rules and conversation overrides carry independent cutoffs: changing TEXT settings does not discard pending DMs. Each changed rule suppresses its pre-change events. More than 1000 retained rule changes in 24 hours folds to an account-wide cutoff to bound metadata safely.

## Rotation and recovery
- If a key rotation results in loss of the recovery key, the correct path is revoke plus explicit re-enroll.
- Do not edit private rows directly.
- Do not restore revoked grants by database rollback.

## No backup job
This repository has an explicit no-backup rule. Never create or recommend `pg_dump` or any backup job as part of notification operations.

## Acceptance vs display vs opened vs read
- **Acceptance** means the provider accepted the message for delivery.
- **Display** means the OS/browser rendered the notification.
- **Opened** means the user interacted with the notification.
- **Read** means the underlying content was marked read in the application.
These are distinct states. Force-stop or force-quit by the OS can prevent display, opened, and read regardless of provider acceptance.

## References
- Firebase HTTP v1 API: https://firebase.google.com/docs/reference/fcm/rest
- Web Push specification: https://www.w3.org/TR/web-push/
- APNs: https://developer.apple.com/documentation/usernotifications

## Enable and verify
1. Apply additive migrations with the existing migrate command; preserve the installation identity.
2. Supply the three operator key files using the explicit `deploy/notifications/compose.guild.yaml` overlay. Set `NOTIFICATIONS_AVAILABLE=true`; for Web also set `NOTIFICATION_WEB_ENABLED=true` and valid VAPID public/contact inputs. The normal compose stays disabled.
3. For mobile, configure only `NOTIFICATION_RELAY_ORIGIN` and the pinned `NOTIFICATION_RELAY_PUBLIC_KEY` supplied by the official publisher. Guild owners do not acquire Apple publisher credentials.
4. The signed official Android/iOS builds and publisher relay have independent platform flags, documented in `publisher.md`. A valid configuration is separate from a successfully enrolled device.
5. Check authenticated device capabilities/settings and the private metrics dashboard. User account opt-in and explicit permission/device enrollment remain separate. Revoke devices from the own-account list.
6. On provider/credential failure, kill sending, investigate bounded reasons/error spans and repair configuration. Resume permits new work only. Keep chat/voice available throughout.
