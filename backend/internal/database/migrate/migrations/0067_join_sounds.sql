CREATE TABLE IF NOT EXISTS join_sounds (
    account_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    id UUID UNIQUE,
    revision BIGINT NOT NULL DEFAULT 0 CHECK (revision >= 0),
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    payload BYTEA,
    duration_ms INTEGER,
    next_upload_at TIMESTAMPTZ NOT NULL DEFAULT '-infinity',
    CHECK ((id IS NULL AND payload IS NULL AND duration_ms IS NULL AND NOT enabled)
        OR (id IS NOT NULL AND payload IS NOT NULL AND duration_ms IS NOT NULL AND octet_length(payload) BETWEEN 1 AND 262144
            AND duration_ms BETWEEN 300 AND 3000 AND revision > 0))
);
