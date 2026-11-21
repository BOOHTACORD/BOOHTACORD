package routeinactivemembers

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

const topologyLock int64 = 441903817

type Service struct {
	database *pgxpool.Pool
	presence *eventhub.Hub
}

func New(database *pgxpool.Pool, presence *eventhub.Hub) Service {
	return Service{database: database, presence: presence}
}

// RouteInactive moves connected users whose most recent authenticated client
// activity exceeded the guild's configured AFK interval. The old lease is
// revoked first; clients receive the destination only after the SFU cleanup
// outbox is dispatched.
func (service Service) RouteInactive(ctx context.Context) (int, error) {
	if service.database == nil || service.presence == nil {
		return 0, nil
	}
	var target *string
	var timeoutSeconds int
	if err := service.database.QueryRow(ctx, `SELECT afk_channel_id::text,afk_timeout_seconds FROM guild_settings WHERE singleton=TRUE`).Scan(&target, &timeoutSeconds); err != nil {
		return 0, fmt.Errorf("read AFK configuration: %w", err)
	}
	if target == nil || timeoutSeconds < 60 {
		return 0, nil
	}
	now := time.Now()
	moved := 0
	for _, userID := range service.presence.OnlineAccounts() {
		last, ok := service.presence.LastActivity(userID)
		if !ok || now.Sub(last) < time.Duration(timeoutSeconds)*time.Second {
			continue
		}
		didMove, err := service.move(ctx, userID, *target)
		if err != nil {
			return moved, err
		}
		if didMove {
			moved++
		}
	}
	return moved, nil
}

func (service Service) move(ctx context.Context, userID, target string) (bool, error) {
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock($1)`, topologyLock); err != nil {
		return false, err
	}
	var currentTarget *string
	var timeoutSeconds int
	if err = tx.QueryRow(ctx, `SELECT afk_channel_id::text,afk_timeout_seconds FROM guild_settings WHERE singleton=TRUE FOR SHARE`).Scan(&currentTarget, &timeoutSeconds); err != nil {
		return false, err
	}
	if currentTarget == nil || *currentTarget != target || timeoutSeconds < 60 {
		return false, tx.Commit(ctx)
	}
	lastActivity, connected := service.presence.LastActivity(userID)
	if !connected || time.Since(lastActivity) < time.Duration(timeoutSeconds)*time.Second {
		return false, tx.Commit(ctx)
	}
	var leaseID, channelID string
	err = tx.QueryRow(ctx, `SELECT lease.id::text,lease.channel_id::text FROM voice_leases lease JOIN channels channel ON channel.id=lease.channel_id WHERE lease.user_id=$1::uuid AND lease.revoked_at IS NULL AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL FOR UPDATE OF lease`, userID).Scan(&leaseID, &channelID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, tx.Commit(ctx)
		}
		return false, err
	}
	if channelID == target {
		return false, tx.Commit(ctx)
	}
	var targetActive bool
	if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM channels WHERE id=$1::uuid AND kind='VOICE' AND archived_at IS NULL AND admission_closed_at IS NULL)`, target).Scan(&targetActive); err != nil {
		return false, err
	}
	if !targetActive {
		return false, tx.Commit(ctx)
	}
	// Serialize the final check and commit with activity and connection changes.
	moved, err := service.presence.IfInactive(userID, time.Now().Add(-time.Duration(timeoutSeconds)*time.Second), func() error {
		return commitAFKMove(ctx, tx, userID, leaseID, channelID, target)
	})
	if err != nil || moved {
		return moved, err
	}
	return false, tx.Commit(ctx)
}
