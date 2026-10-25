package controldelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
)

type Policy struct {
	Enabled         bool
	Epoch           int64
	IntentPending   int
	DeliveryPending int
	MaxIntents      int
	MaxDeliveries   int
	GraceSeconds    int
	TTLSeconds      int
	SoundSeconds    int
}

// All queue writers lock policy before queue rows, preserving both bounded
// counters and a consistent lock order across claims, planning and kill switch.
func Lock(ctx context.Context, tx pgx.Tx) (Policy, error) {
	var p Policy
	err := tx.QueryRow(ctx, `SELECT operator_enabled AND NOT kill_switch,epoch,intent_pending,delivery_pending,max_intents,max_deliveries,grace_seconds,ttl_seconds,sound_seconds
 FROM notification_runtime_policy WHERE singleton FOR UPDATE`).Scan(&p.Enabled, &p.Epoch, &p.IntentPending, &p.DeliveryPending, &p.MaxIntents, &p.MaxDeliveries, &p.GraceSeconds, &p.TTLSeconds, &p.SoundSeconds)
	return p, err
}
