package registerdevice

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"
)

var ErrInvalid = errors.New("invalid notification device")
var ErrConflict = errors.New("notification device generation conflict")
var ErrUnavailable = errors.New("notification transport unavailable")
var ErrUnauthorized = errors.New("notification issuing session inactive")
var ErrLimit = errors.New("notification device limit reached")

type Subscription struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256DH string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
}
type Input struct {
	ID                 string            `json:"-"`
	AccountID          string            `json:"-"`
	SessionDigest      [sha256.Size]byte `json:"-"`
	InstanceID         string            `json:"instance_id"`
	ExpectedGeneration int64             `json:"expected_generation"`
	Transport          string            `json:"transport"`
	Namespace          string            `json:"namespace"`
	Permission         string            `json:"permission"`
	ConsentVersion     int               `json:"consent_version"`
	Subscription       *Subscription     `json:"subscription,omitempty"`
}
type Record struct {
	ID               string            `json:"id"`
	InstanceID       string            `json:"instance_id"`
	Transport        string            `json:"transport"`
	Namespace        string            `json:"namespace"`
	Generation       int64             `json:"generation"`
	State            string            `json:"state"`
	Permission       string            `json:"permission"`
	ExpiresAt        time.Time         `json:"expires_at"`
	Origin           string            `json:"origin"`
	InstallationID   string            `json:"installation_id"`
	SessionRef       string            `json:"session_ref"`
	AccountID        string            `json:"-"`
	SessionDigest    [sha256.Size]byte `json:"-"`
	SecretCipher     []byte            `json:"-"`
	Fingerprint      [sha256.Size]byte `json:"-"`
	RegistrationHash [sha256.Size]byte `json:"-"`
	NonceDigest      []byte            `json:"-"`
	EnrollmentUntil  *time.Time        `json:"-"`
	ConsentAt        time.Time         `json:"consent_at"`
	CreatedAt        time.Time         `json:"created_at"`
	UpdatedAt        time.Time         `json:"-"`
}

func (r Record) Scope() string {
	return strings.Join([]string{"notification-binding/v1", r.Origin, r.InstallationID, r.AccountID, hex.EncodeToString(r.SessionDigest[:]), r.ID, r.InstanceID, r.Transport, r.Namespace, strconv.FormatInt(r.Generation, 10)}, "\x00")
}

type Enrollment struct {
	Device Record `json:"device"`
	Nonce  string `json:"nonce,omitempty"`
}
