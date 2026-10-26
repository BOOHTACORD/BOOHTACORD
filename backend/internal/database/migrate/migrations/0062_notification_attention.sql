CREATE TABLE IF NOT EXISTS notification_attention (
 account_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 session_digest bytea NOT NULL REFERENCES sessions(token_digest),
 view_id uuid NOT NULL,
 kind text NOT NULL CHECK(kind IN('CHANNEL','DIRECT_MESSAGE')),
 conversation_id uuid NOT NULL,
 expires_at timestamptz NOT NULL,
 PRIMARY KEY(account_id,session_digest,view_id)
);
CREATE INDEX IF NOT EXISTS notification_attention_expiry ON notification_attention(expires_at);
CREATE INDEX IF NOT EXISTS notification_attention_conversation ON notification_attention(account_id,kind,conversation_id,expires_at);
