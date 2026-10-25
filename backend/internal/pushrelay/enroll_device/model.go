package enrolldevice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/notifications/secretbox"
)

var ErrInvalid = errors.New("invalid relay enrollment")
var ErrConflict = errors.New("relay enrollment conflict")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Service struct {
	Database  Database
	Box       *secretbox.Box
	Namespace string
	Platforms map[string]bool
}
type Challenge struct {
	Target     string `json:"target"`
	TargetKind string `json:"target_kind"`
	PublicKey  string `json:"public_key"`
	Platform   string `json:"platform"`
	Namespace  string `json:"namespace"`
}
type Enrollment struct {
	Version   int       `json:"version"`
	DeviceID  string    `json:"device_id"`
	State     string    `json:"state"`
	ExpiresAt time.Time `json:"expires_at"`
}
type Proof struct {
	ChallengeID string `json:"challenge_id"`
	Nonce       string `json:"nonce"`
}

func DeviceScope(id, namespace, kind, platform string, public []byte) string {
	fingerprint := sha256.Sum256(public)
	return "relay-device/v1\x00" + namespace + "\x00" + id + "\x00" + kind + "\x00" + platform + "\x00" + hex.EncodeToString(fingerprint[:])
}
func JobScope(id, device, grant, kind, namespace, ref string) string {
	return "relay-job/v1\x00" + id + "\x00" + device + "\x00" + grant + "\x00" + kind + "\x00" + namespace + "\x00" + ref
}
