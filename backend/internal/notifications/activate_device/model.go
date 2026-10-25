package activatedevice

import (
	"context"
	"crypto/ed25519"
	"errors"
	"github.com/jackc/pgx/v5"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	"voice-platform/backend/internal/notifications/secretbox"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

var ErrNotFound = errors.New("notification enrollment unavailable")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Service struct {
	Database              Database
	Box                   *secretbox.Box
	Scope                 reader.Scope
	RelayPublicKey        ed25519.PublicKey
	InstallationPublicKey string
}
type Input struct {
	ExpectedGeneration int64           `json:"expected_generation"`
	Receipt            receipt.Receipt `json:"receipt"`
}
