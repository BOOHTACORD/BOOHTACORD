package observedelivery

import (
	"context"
	"github.com/jackc/pgx/v5/pgconn"
)

type Executor interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

var reasons = map[string]bool{
	"none": true, "eligible": true, "unavailable": true, "no_consent": true, "self": true, "event_kind": true, "deleted": true, "archived": true, "revoked": true, "read": true, "expired": true, "paused": true, "muted": true, "not_mentioned": true, "unsupported_version": true, "invalid": true,
	"preference_changed": true, "device_enabled": true, "target_unavailable": true, "settings_unavailable": true, "queue_full": true, "quota": true, "grouped": true, "attention": true, "generation_changed": true, "operator_disabled": true, "configuration_error": true, "provider_error": true, "invalid_binding": true, "transport_unknown": true, "lease_expired": true, "other": true,
}

func Reason(reason string) string {
	if reason == "" {
		return "none"
	}
	if !reasons[reason] {
		return "other"
	}
	return reason
}

func Record(ctx context.Context, db Executor, metric, reason, transport string, amount int64) error {
	if !reasons[reason] {
		reason = "other"
	}
	if transport != "web_push" && transport != "mobile_relay" {
		transport = "none"
	}
	if amount <= 0 {
		return nil
	}
	_, err := db.Exec(ctx, `INSERT INTO notification_counters(metric,reason,transport,value)VALUES($1,$2,$3,$4)
 ON CONFLICT(metric,reason,transport)DO UPDATE SET value=notification_counters.value+$4`, metric, reason, transport, amount)
	return err
}
