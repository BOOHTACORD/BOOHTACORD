ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Preserve sessions that existed before this policy while giving them a bounded transition period.
UPDATE sessions SET expires_at = now() + interval '180 days' WHERE expires_at IS NULL;

ALTER TABLE sessions
    ALTER COLUMN expires_at SET DEFAULT (now() + interval '180 days'),
    ALTER COLUMN expires_at SET NOT NULL;
