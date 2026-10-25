package registerdevicepostgres

const insertDevice = `INSERT INTO notification_devices(id,account_id,session_digest,installation_id,origin,instance_id,
 transport,namespace,generation,state,permission,secret_cipher,fingerprint,nonce_digest,enrollment_until,
 expires_at,consent_version,consent_at,created_at,updated_at,registration_hash)
 VALUES($1::uuid,$2::uuid,$3,$4::uuid,$5,$6::uuid,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,1,$17,$18,$19,$20)
 ON CONFLICT DO NOTHING RETURNING created_at,consent_at`

const updateDevice = `UPDATE notification_devices SET generation=$9,state=$10,permission=$11,secret_cipher=$12,
 fingerprint=$13,nonce_digest=$14,enrollment_until=$15,expires_at=$16,updated_at=$19,registration_hash=$20,
 consent_at=CASE WHEN state='active' AND expires_at>$19 THEN consent_at ELSE $17 END
 WHERE id=$1::uuid AND account_id=$2::uuid AND session_digest=$3 AND installation_id=$4::uuid AND origin=$5
 AND instance_id=$6::uuid AND transport=$7 AND namespace=$8 AND generation=$21
 AND consent_at<=$17 AND created_at<=$18
 RETURNING created_at,consent_at`
