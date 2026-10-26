CREATE TABLE IF NOT EXISTS notification_groups (
 binding_id uuid NOT NULL REFERENCES notification_devices(id) ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN('TEXT','DM')),
 conversation_id uuid NOT NULL,
 generation bigint NOT NULL,
 group_ref uuid NOT NULL DEFAULT gen_random_uuid(),
 ref_until timestamptz NOT NULL,
 last_signaled_at timestamptz,
 reservation_job uuid,
 reservation_until timestamptz,
 updated_at timestamptz NOT NULL,
 PRIMARY KEY(binding_id,kind,conversation_id)
);
CREATE TABLE IF NOT EXISTS notification_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 outbox_id uuid NOT NULL REFERENCES notification_outbox(id) ON DELETE CASCADE,
 binding_id uuid NOT NULL REFERENCES notification_devices(id) ON DELETE CASCADE,
 binding_generation bigint NOT NULL,
 account_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN('TEXT','DM')),
 conversation_id uuid NOT NULL,
 message_id uuid NOT NULL,
 template text NOT NULL CHECK(template IN('direct_message','mention','activity')),
 group_ref uuid NOT NULL,
 created_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 due_at timestamptz NOT NULL,
 epoch bigint NOT NULL,
 state text NOT NULL DEFAULT 'pending' CHECK(state IN('pending','claimed','retry','accepted_by_relay','accepted_by_provider','suppressed','expired','permanent_failure','delivery_unknown')),
 reason text NOT NULL DEFAULT '' CHECK(length(reason)<=40),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 10),
 attempt_started_at timestamptz,
 lease_owner uuid,
 lease_until timestamptz,
 accepted_at timestamptz,
 presented_at timestamptz,
 hint_emitted_at timestamptz,
 opened_at timestamptz,
 UNIQUE(kind,message_id,account_id,binding_id)
);
CREATE INDEX IF NOT EXISTS notification_deliveries_due ON notification_deliveries(due_at,id) WHERE state IN('pending','claimed','retry');
CREATE INDEX IF NOT EXISTS notification_deliveries_retention ON notification_deliveries(expires_at);
CREATE TABLE IF NOT EXISTS notification_dispatch_budgets (
 scope text NOT NULL CHECK(scope IN('sender','recipient','installation')),
 subject uuid NOT NULL,
 window_start timestamptz NOT NULL,
 attempts integer NOT NULL CHECK(attempts BETWEEN 1 AND 1001),
 PRIMARY KEY(scope,subject)
);
CREATE INDEX IF NOT EXISTS notification_dispatch_budget_age ON notification_dispatch_budgets(window_start);
