package supportcontact

// An assignment cannot rewrite any direct_messages participant or message row.
// The existing active-account row lock serializes this change with blocking.
const assignContact = `WITH eligible AS (
 SELECT id FROM users WHERE id=$1::uuid AND blocked_at IS NULL FOR SHARE
), configured AS (
 UPDATE support_contact_configuration SET support_account_id=$1::uuid, revision=revision+1,updated_at=now()
 WHERE singleton=true AND ($1::uuid IS NULL OR EXISTS(SELECT 1 FROM eligible))
 RETURNING revision,support_account_id
), audited AS (
 INSERT INTO audit_events(event_type,target_user_id,metadata)
 SELECT 'SUPPORT_CONTACT_CHANGED',support_account_id,jsonb_build_object('revision',revision,'enabled',support_account_id IS NOT NULL)
 FROM configured RETURNING id
)
SELECT revision FROM configured WHERE EXISTS(SELECT 1 FROM audited)`
