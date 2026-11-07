package soundpostgres

const readSQL = `SELECT revision, settings FROM voice_sound_preferences WHERE account_id = $1::uuid`
const saveSQL = `
WITH updated AS (
 UPDATE voice_sound_preferences SET revision = revision + 1, settings = $2::jsonb, updated_at = now()
 WHERE account_id = $1::uuid AND revision = $3::bigint AND $3::bigint > 0
 RETURNING revision, settings
), inserted AS (
 INSERT INTO voice_sound_preferences(account_id, revision, settings)
 SELECT $1::uuid, 1, $2::jsonb WHERE $3::bigint = 0
 ON CONFLICT (account_id) DO NOTHING RETURNING revision, settings
)
SELECT revision, settings FROM updated UNION ALL SELECT revision, settings FROM inserted`
