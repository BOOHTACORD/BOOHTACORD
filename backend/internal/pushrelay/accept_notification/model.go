package acceptnotification

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	"voice-platform/backend/internal/notifications/secretbox"
)

var ErrInvalid = errors.New("invalid relay notification")
var ErrConflict = errors.New("relay notification reference conflict")
var ErrRouteUnavailable = errors.New("relay route unavailable")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Service struct {
	Database  Database
	Box       *secretbox.Box
	Namespace string
	Platforms map[string]bool
}
type Input struct {
	GrantID string           `json:"grant_id"`
	Payload delivery.Payload `json:"payload"`
}
type Status struct {
	Version   int       `json:"version"`
	JobRef    string    `json:"job_ref"`
	State     string    `json:"state"`
	ExpiresAt time.Time `json:"expires_at"`
}
type route struct {
	Device, Binding, Platform string
	Generation                int64
	ExpiresAt                 time.Time
}

func matches(raw []byte, in Input) bool {
	var decoded Input
	return json.Unmarshal(raw, &decoded) == nil && decoded == in
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
