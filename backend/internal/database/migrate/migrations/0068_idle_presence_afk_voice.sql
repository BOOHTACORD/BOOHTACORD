ALTER TABLE guild_settings
    ADD COLUMN IF NOT EXISTS afk_channel_id UUID REFERENCES channels(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS afk_timeout_seconds INTEGER NOT NULL DEFAULT 0
        CHECK (afk_timeout_seconds = 0 OR afk_timeout_seconds BETWEEN 60 AND 86400),
    DROP CONSTRAINT IF EXISTS guild_settings_afk_enabled_pair_check,
    ADD CONSTRAINT guild_settings_afk_enabled_pair_check
        CHECK ((afk_channel_id IS NULL AND afk_timeout_seconds = 0) OR
               (afk_channel_id IS NOT NULL AND afk_timeout_seconds BETWEEN 60 AND 86400));

ALTER TABLE voice_leases DROP CONSTRAINT IF EXISTS voice_leases_revocation_reason_check,
    ADD CONSTRAINT voice_leases_revocation_reason_check
        CHECK (revocation_reason IN ('TRANSFER', 'KICK', 'CHANNEL_CLOSED', 'SESSION_REVOKED', 'BANNED', 'LOGOUT', 'VOLUNTARY_LEAVE', 'AFK_MOVE'));

ALTER TABLE voice_sfu_revocations
    ADD COLUMN IF NOT EXISTS target_channel_id UUID REFERENCES channels(id) ON DELETE RESTRICT;
