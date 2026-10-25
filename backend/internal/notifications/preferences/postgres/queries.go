package preferencespostgres

const readPreferences = `
SELECT COALESCE((
    SELECT settings FROM notification_preferences WHERE account_id = $1
), jsonb_build_object(
    'version', 1, 'revision', 0, 'enabled', false, 'imported', false,
    'dm', jsonb_build_object('mode', 'all'),
    'text', jsonb_build_object('mode', 'mentions'),
    'overrides', '[]'::jsonb
))`

const savePreferences = `
WITH updated AS (
 UPDATE notification_preferences AS row
 SET revision = row.revision + 1, updated_at = now(),
     settings = $2::jsonb || jsonb_build_object('version', 1,
         'revision', row.revision + 1, 'imported', row.imported)
 WHERE row.account_id = $1::uuid AND row.revision = $3::bigint
   AND $3::bigint > 0 AND NOT $4::bool
 RETURNING account_id::text, version, revision, imported, settings
), inserted AS (
 INSERT INTO notification_preferences(account_id, version, revision, imported, settings)
 SELECT $1::uuid, 1, 1, $4::bool,
   CASE WHEN $4::bool THEN jsonb_build_object('version', 1, 'revision', 1,
     'enabled', false, 'imported', true, 'dm', jsonb_build_object('mode', 'all'),
     'text', jsonb_build_object('mode', 'mentions'),
     'overrides', COALESCE(NULLIF($2::jsonb->'overrides','null'::jsonb),'[]'::jsonb))
   ELSE $2::jsonb || jsonb_build_object('version',1,'revision',1,'imported',false) END
 WHERE $3::bigint = 0
 ON CONFLICT (account_id) DO NOTHING
 RETURNING account_id::text, version, revision, imported, settings
)
SELECT * FROM updated UNION ALL SELECT * FROM inserted`

const currentImported = `
SELECT imported FROM notification_preferences WHERE account_id = $1`
