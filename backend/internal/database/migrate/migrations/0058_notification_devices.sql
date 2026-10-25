CREATE TABLE IF NOT EXISTS notification_devices (
 id uuid PRIMARY KEY,
 account_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 session_digest bytea NOT NULL REFERENCES sessions(token_digest),
 installation_id uuid NOT NULL,
 origin text NOT NULL CHECK(length(origin) BETWEEN 8 AND 2048),
 instance_id uuid NOT NULL,
 transport text NOT NULL CHECK(transport IN('web_push','mobile_relay')),
 namespace text NOT NULL CHECK(namespace IN('staging','production')),
 generation bigint NOT NULL CHECK(generation BETWEEN 1 AND 1000000000),
 state text NOT NULL CHECK(state IN('registering','active','stale','permission_denied','invalid','revoked')),
 permission text NOT NULL CHECK(permission IN('granted','provisional')),
 consent_version integer NOT NULL CHECK(consent_version=1),
 consent_at timestamptz NOT NULL,
 secret_cipher bytea,
 fingerprint bytea NOT NULL CHECK(octet_length(fingerprint)=32),
 registration_hash bytea NOT NULL CHECK(octet_length(registration_hash)=32),
 nonce_digest bytea,
 enrollment_until timestamptz,
 expires_at timestamptz NOT NULL,
 updated_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL,
 CHECK((state='active' AND secret_cipher IS NOT NULL) OR state<>'active')
);
CREATE UNIQUE INDEX IF NOT EXISTS notification_device_active_destination
 ON notification_devices(installation_id,transport,namespace,fingerprint)
 WHERE state IN('registering','active');
CREATE INDEX IF NOT EXISTS notification_device_account ON notification_devices(account_id,state);
-- Retained revoked rows fence late registration callbacks for the same profile.
CREATE UNIQUE INDEX IF NOT EXISTS notification_device_profile
 ON notification_devices(installation_id,origin,instance_id,transport,namespace);
CREATE INDEX IF NOT EXISTS notification_device_session ON notification_devices(session_digest,state);
CREATE INDEX IF NOT EXISTS notification_device_expiry ON notification_devices(expires_at);
