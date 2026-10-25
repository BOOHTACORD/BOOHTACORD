package readdeliverycontext

import (
	"context"
	"time"
	"voice-platform/backend/internal/identity/session"
	d "voice-platform/backend/internal/notifications/register_device"
)

type Scope struct{ Origin, InstallationID, Namespace string }

const CandidatePageSize = 10
const candidatePrefix = `SELECT p.account_id::text FROM notification_preferences p JOIN users u ON u.id=p.account_id
 WHERE p.account_id>$1::uuid AND p.account_id<>$2::uuid AND u.blocked_at IS NULL
 AND p.settings->>'enabled'='true' AND `
const textInterest = `(p.account_id=ANY($4::uuid[]) OR COALESCE(
 (SELECT preference->>'mode' FROM jsonb_array_elements(p.settings->'overrides') preference
 WHERE preference->>'kind'='CHANNEL' AND preference->>'id'=$3::uuid::text LIMIT 1),p.settings->'text'->>'mode')='all')`
const directInterest = `EXISTS(SELECT 1 FROM direct_messages dm WHERE dm.id=$3::uuid
 AND $2::uuid IN(dm.participant_one_id,dm.participant_two_id) AND p.account_id IN(dm.participant_one_id,dm.participant_two_id))
 AND cardinality($4::uuid[])>=0`
const candidateSuffix = ` AND EXISTS(SELECT 1 FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest
 WHERE d.account_id=p.account_id AND s.user_id=d.account_id AND d.installation_id=$5::uuid AND d.origin=$6 AND d.namespace=$7
 AND d.state='active' AND d.consent_version=1 AND d.consent_at<=$10 AND d.expires_at>$8 AND s.revoked_at IS NULL
 AND s.expires_at>$8 AND s.last_active_at>$8-($9::double precision*interval '1 second')) ORDER BY p.account_id LIMIT 10`

func (r Reader) Candidates(ctx context.Context, m Message, original []string, cursor string, scope Scope, now time.Time) ([]string, error) {
	interest := textInterest
	if m.Kind == "DM" {
		interest = directInterest
	}
	if original == nil {
		original = []string{}
	}
	rows, err := r.database.Query(ctx, candidatePrefix+interest+candidateSuffix, cursor, m.AuthorID, m.ConversationID, original, scope.InstallationID, scope.Origin, scope.Namespace, now, int64(session.IdleLifetime.Seconds()), m.CreatedAt)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]string, 0, CandidatePageSize)
	for rows.Next() {
		var account string
		if err = rows.Scan(&account); err != nil {
			return nil, err
		}
		result = append(result, account)
	}
	return result, rows.Err()
}
func (r Reader) Devices(ctx context.Context, account string, scope Scope, now time.Time) ([]d.Record, error) {
	rows, err := r.database.Query(ctx, `SELECT d.id::text,d.instance_id::text,d.transport,d.generation,d.permission,d.expires_at,d.consent_at
 FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest JOIN users u ON u.id=d.account_id
 WHERE d.account_id=$1::uuid AND d.origin=$2 AND d.installation_id=$3::uuid AND d.namespace=$4 AND d.state='active'
 AND d.consent_version=1 AND d.expires_at>$5 AND s.user_id=d.account_id AND s.revoked_at IS NULL AND s.expires_at>$5
 AND s.last_active_at>$5-($6::double precision*interval '1 second') AND u.blocked_at IS NULL ORDER BY d.id LIMIT 10`, account, scope.Origin, scope.InstallationID, scope.Namespace, now, int64(session.IdleLifetime.Seconds()))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]d.Record, 0, 10)
	for rows.Next() {
		node := d.Record{AccountID: account, Origin: scope.Origin, InstallationID: scope.InstallationID, Namespace: scope.Namespace, State: "active"}
		if err = rows.Scan(&node.ID, &node.InstanceID, &node.Transport, &node.Generation, &node.Permission, &node.ExpiresAt, &node.ConsentAt); err != nil {
			return nil, err
		}
		result = append(result, node)
	}
	return result, rows.Err()
}
