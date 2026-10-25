CREATE TABLE IF NOT EXISTS notification_preferences (
    account_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    version INT NOT NULL CHECK (version = 1),
    revision BIGINT NOT NULL DEFAULT 0 CHECK (revision >= 0),
    imported BOOLEAN NOT NULL DEFAULT FALSE,
    settings JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
