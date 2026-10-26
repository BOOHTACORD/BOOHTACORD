package centralgateway

import (
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"github.com/google/uuid"
	"strconv"
	"time"
	identity "voice-platform/backend/internal/observability/installation"
)

type Enrollment struct {
	InstallationID string `json:"installation_id"`
	PublicKey      string `json:"public_key"`
	Timestamp      int64  `json:"timestamp"`
	Nonce          string `json:"nonce"`
	Signature      string `json:"signature"`
}
type EnrollmentResponse struct {
	Credential     string `json:"credential"`
	InstallationID string `json:"installation_id"`
	PolicyVersion  int    `json:"policy_version"`
}

func enrollmentMessage(e Enrollment) []byte {
	return []byte("boohtacord/enrollment/v1\x00" + e.InstallationID + "\x00" + e.PublicKey + "\x00" + strconv.FormatInt(e.Timestamp, 10) + "\x00" + e.Nonce)
}
func SignEnrollment(e Enrollment, key ed25519.PrivateKey) string {
	return base64.RawURLEncoding.EncodeToString(ed25519.Sign(key, enrollmentMessage(e)))
}
func NewEnrollment(i identity.Identity, now time.Time) Enrollment {
	nonce := make([]byte, 16)
	if _, err := rand.Read(nonce); err != nil {
		panic("enrollment entropy unavailable")
	}
	e := Enrollment{InstallationID: i.ID, PublicKey: base64.RawURLEncoding.EncodeToString(i.PrivateKey().Public().(ed25519.PublicKey)), Timestamp: now.Unix(), Nonce: hex.EncodeToString(nonce)}
	e.Signature = SignEnrollment(e, i.PrivateKey())
	return e
}
func verifyEnrollment(e Enrollment, now time.Time) ([]byte, bool) {
	id, err := uuid.Parse(e.InstallationID)
	if err != nil || id.String() != e.InstallationID || id.Version() != 4 || e.Timestamp < now.Add(-2*time.Minute).Unix() || e.Timestamp > now.Add(30*time.Second).Unix() {
		return nil, false
	}
	nonce, err := hex.DecodeString(e.Nonce)
	if err != nil || len(nonce) != 16 {
		return nil, false
	}
	key, err := base64.RawURLEncoding.DecodeString(e.PublicKey)
	if err != nil || len(key) != ed25519.PublicKeySize {
		return nil, false
	}
	sig, err := base64.RawURLEncoding.DecodeString(e.Signature)
	return key, err == nil && ed25519.Verify(key, enrollmentMessage(e), sig)
}
func credential(key []byte, r Record) string {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte("boohtacord/write-only/v1\x00" + r.ID + "\x00" + strconv.FormatInt(r.Epoch, 10)))
	mac.Write(r.PublicKey)
	return r.ID + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
func jsonResponse(w interface{ Write([]byte) (int, error) }, v any) { _ = json.NewEncoder(w).Encode(v) }
