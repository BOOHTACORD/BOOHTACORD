# ADR-030: consent-bound addressed notifications

Status: implementation accepted for #554; platform delivery evidence is separate.

PostgreSQL is the authority for preferences, device/session generations, message
eligibility and notification intent. New TEXT/DM commits create metadata-only
intents atomically. Replay, welcome, edit, presence and self events do not create
new addressed deliveries. Provider I/O is outside database transactions.

Web uses the installation's own VAPID identity and browser push services.
Official mobile builds use a separately deployed publisher relay with FCM;
iOS transport terminates through APNs. Self-hosted operators never receive
publisher credentials, raw mobile tokens or arbitrary-send authority. No Firebase
Auth/Analytics, Redis, Kafka, central product account or new notification inbox.

Operator availability, account rules and device/provider consent are independent.
Defaults shown at opt-in are DM=all, TEXT=mentions; old implicit Web all is local
behavior, not consent. Only explicit local overrides have a preview/import path.
Server revision0 can import once; an existing server choice conflicts visibly.
Device sound/OS permission remain local. Muting does not modify read cursors.

Every registration and resolve derives actor/session from authenticated context.
DM participants retain their exclusive access; administrators have no bypass.
Binding scope includes trusted origin/installation, account, issuing session,
device instance, provider namespace and generation. Encryption keys are outside
the DB. Existing installation identity is reused independently of telemetry consent.

Remote data is versioned, neutral and bounded: opaque references, template enum,
expiry and grouping reference. No body, name, file, credential or arbitrary URL.
Tap restores a previously paired session, resolves under current ACL and uses
existing navigation; it neither marks read nor starts media. Revocation stops
new sends; already accepted neutral provider alerts cannot always be recalled.

Proposed configurable defaults: grace5s, attention30s, sound window60s, external
TTL1h, terminal metadata retention7d. Retries never extend expiry. Attention is
bounded and does not replace read. Queue, fanout, retries and concurrency are
bounded. Ambiguous timeout remains delivery_unknown; acceptance is not delivery.

Web sender validates HTTPS provider hosts and every DNS answer, pins dialing,
rejects private/metadata addresses and redirects, and inherits no environment proxy.
Mobile relay pins installation signing identity after device-approved pairing,
proves route possession, checks tenant/grant ownership and replay, enforces quotas
and permits independent device revoke. Both use fixed neutral visible templates.

Rollout is opt-in. Missing keys/providers means local-only/unavailable while chat
and voice remain usable. Kill switch prevents new sends and quarantines pending
work; re-enable cannot replay expired history. This change creates no backup job.

Physical iPhone/Android, Safari/iOS PWA and real provider delivery require separate
staging inputs. Unit/browser/fake-provider evidence never substitutes for that gate.
