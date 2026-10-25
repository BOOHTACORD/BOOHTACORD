CREATE TABLE IF NOT EXISTS notification_runtime_policy (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 operator_enabled boolean NOT NULL DEFAULT false,
 kill_switch boolean NOT NULL DEFAULT false,
 epoch bigint NOT NULL DEFAULT 1 CHECK(epoch>0),
 intent_pending integer NOT NULL DEFAULT 0 CHECK(intent_pending>=0),
 delivery_pending integer NOT NULL DEFAULT 0 CHECK(delivery_pending>=0),
 max_intents integer NOT NULL DEFAULT 10000 CHECK(max_intents BETWEEN 1 AND 100000),
 max_deliveries integer NOT NULL DEFAULT 10000 CHECK(max_deliveries BETWEEN 1 AND 100000),
 grace_seconds integer NOT NULL DEFAULT 5 CHECK(grace_seconds BETWEEN 0 AND 30),
 ttl_seconds integer NOT NULL DEFAULT 3600 CHECK(ttl_seconds BETWEEN 60 AND 86400),
 sound_seconds integer NOT NULL DEFAULT 60 CHECK(sound_seconds BETWEEN 1 AND 3600),
 sender_per_minute integer NOT NULL DEFAULT 100 CHECK(sender_per_minute BETWEEN 1 AND 1000),
 dropped_intents bigint NOT NULL DEFAULT 0,
 budget_drops bigint NOT NULL DEFAULT 0
);
INSERT INTO notification_runtime_policy(singleton) VALUES(true) ON CONFLICT(singleton) DO NOTHING;
CREATE TABLE IF NOT EXISTS notification_counters (
 metric text NOT NULL CHECK(metric IN('intent_created','eligible','suppressed','attempt','relay_accepted','provider_accepted','retry','expired','invalid_binding','ambiguous','permanent_failure','opened','read','queue_drop')),
 reason text NOT NULL CHECK(length(reason)<=40),
 transport text NOT NULL CHECK(transport IN('none','web_push','mobile_relay')),
 value bigint NOT NULL DEFAULT 0 CHECK(value>=0),
 PRIMARY KEY(metric,reason,transport)
);
CREATE TABLE IF NOT EXISTS notification_sender_budgets (
 account_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
 window_start timestamptz NOT NULL,
 attempts integer NOT NULL CHECK(attempts>0)
);
CREATE INDEX IF NOT EXISTS notification_sender_budget_age ON notification_sender_budgets(window_start);
CREATE TABLE IF NOT EXISTS notification_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 installation_id uuid NOT NULL,
 message_id uuid NOT NULL,
 conversation_id uuid NOT NULL,
 kind text NOT NULL CHECK(kind IN('TEXT','DM')),
 author_id uuid NOT NULL,
 mention_user_ids uuid[] NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 due_at timestamptz NOT NULL,
 epoch bigint NOT NULL,
 state text NOT NULL DEFAULT 'pending' CHECK(state IN('pending','planning','done','suppressed','expired')),
 reason text NOT NULL DEFAULT '' CHECK(length(reason)<=40),
 cursor_account uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
 lease_owner uuid,
 lease_until timestamptz,
 UNIQUE(kind,message_id)
);
CREATE INDEX IF NOT EXISTS notification_outbox_due ON notification_outbox(due_at,id) WHERE state IN('pending','planning');
CREATE INDEX IF NOT EXISTS notification_outbox_retention ON notification_outbox(expires_at);
