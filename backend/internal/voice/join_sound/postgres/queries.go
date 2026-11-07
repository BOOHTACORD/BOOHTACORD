package soundstore

const reserveSQL = `INSERT INTO join_sounds(account_id,next_upload_at)
 SELECT id,now()+interval '10 seconds' FROM users WHERE id=$1 AND blocked_at IS NULL
 ON CONFLICT(account_id) DO UPDATE SET next_upload_at=now()+interval '10 seconds'
 WHERE join_sounds.next_upload_at<=now() RETURNING true`
const replaceSQL = `UPDATE join_sounds SET id=$2,revision=revision+1,enabled=true,payload=$3,duration_ms=$4
 WHERE account_id=$1 AND EXISTS(SELECT 1 FROM users WHERE id=$1 AND blocked_at IS NULL)
 RETURNING id,account_id,revision,enabled,payload,duration_ms`
const fetchSQL = `SELECT sound.id,sound.account_id,sound.revision,sound.enabled,sound.payload,sound.duration_ms
 FROM join_sounds sound JOIN users owner ON owner.id=sound.account_id
 JOIN users viewer ON viewer.id=$1
 WHERE sound.id=$3 AND owner.blocked_at IS NULL AND viewer.blocked_at IS NULL
 AND EXISTS(SELECT 1 FROM sessions auth WHERE auth.token_digest=$2 AND auth.user_id=$1
   AND auth.revoked_at IS NULL AND auth.expires_at>now())
 AND (sound.account_id=$1 OR (sound.enabled AND EXISTS(
  SELECT 1 FROM voice_leases listener JOIN voice_leases speaker ON speaker.channel_id=listener.channel_id
  JOIN channels room ON room.id=listener.channel_id
  JOIN sessions speaker_auth ON speaker_auth.token_digest=speaker.session_token_digest
  WHERE listener.user_id=$1 AND listener.session_token_digest=$2 AND listener.revoked_at IS NULL
   AND speaker.user_id=sound.account_id AND speaker.revoked_at IS NULL
   AND speaker_auth.revoked_at IS NULL AND speaker_auth.expires_at>now()
   AND room.kind='VOICE' AND room.archived_at IS NULL)))`
