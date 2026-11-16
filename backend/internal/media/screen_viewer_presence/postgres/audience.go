package postgres

const activeWatchers = `
SELECT DISTINCT viewer.id::text, viewer.user_id::text
FROM voice_leases AS owner
JOIN sessions AS owner_session ON owner_session.token_digest = owner.session_token_digest AND owner_session.user_id = owner.user_id
JOIN channels AS channel ON channel.id = owner.channel_id
JOIN users AS owner_account ON owner_account.id = owner.user_id
JOIN voice_leases AS viewer ON viewer.channel_id = owner.channel_id AND viewer.id = ANY($2::uuid[])
JOIN sessions AS viewer_session ON viewer_session.token_digest = viewer.session_token_digest AND viewer_session.user_id = viewer.user_id
JOIN users AS viewer_account ON viewer_account.id = viewer.user_id
WHERE owner.id = $1 AND owner.revoked_at IS NULL AND owner_session.revoked_at IS NULL
  AND viewer.revoked_at IS NULL AND viewer_session.revoked_at IS NULL
  AND channel.kind = 'VOICE' AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL
  AND owner_account.blocked_at IS NULL AND viewer_account.blocked_at IS NULL`
