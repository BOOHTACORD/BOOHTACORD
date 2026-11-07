CREATE TABLE voice_sound_preferences (
    account_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL CHECK (revision > 0),
    settings JSONB NOT NULL CHECK (jsonb_typeof(settings) = 'object'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
