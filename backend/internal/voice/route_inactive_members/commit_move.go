package routeinactivemembers

import (
	"context"

	"github.com/jackc/pgx/v5"
)

func commitAFKMove(ctx context.Context, tx pgx.Tx, userID, leaseID, channelID, target string) error {
	var revoked string
	if err := tx.QueryRow(ctx, `UPDATE voice_leases SET revoked_at=clock_timestamp(),revocation_reason='AFK_MOVE' WHERE id=$1::uuid AND revoked_at IS NULL RETURNING id::text`, leaseID).Scan(&revoked); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO voice_sfu_revocations(lease_id,channel_id,target_channel_id) VALUES($1::uuid,$2::uuid,$3::uuid) ON CONFLICT(lease_id) DO NOTHING`, leaseID, channelID, target); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO audit_events(actor_user_id,target_user_id,event_type,metadata) VALUES($1::uuid,$1::uuid,'VOICE_MEMBER_MOVED_TO_AFK',jsonb_build_object('lease_id',$2::text,'from_channel_id',$3::text,'to_channel_id',$4::text))`, userID, leaseID, channelID, target); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
