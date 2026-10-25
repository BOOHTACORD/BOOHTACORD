package registerdevice

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
	"time"
	"voice-platform/backend/internal/notifications/secretbox"
)

type storeSpy struct {
	record Record
	calls  int
}

func (s *storeSpy) Register(_ context.Context, r Record, _ int64) (Record, error) {
	s.record = r
	s.calls++
	return r, nil
}

type gateSpy struct{ err error }

func (g gateSpy) Validate(context.Context, string) error { return g.err }
func webInput(t *testing.T) Input {
	key, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	in := Input{AccountID: "11111111-1111-4111-8111-111111111111", InstanceID: "22222222-2222-4222-8222-222222222222", Transport: "web_push", Namespace: "staging", Permission: "granted", ConsentVersion: 1, SessionDigest: [32]byte{1}}
	in.Subscription = &Subscription{Endpoint: "https://push.example.invalid/opaque"}
	in.Subscription.Keys.P256DH = base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes())
	in.Subscription.Keys.Auth = base64.RawURLEncoding.EncodeToString(make([]byte, 16))
	return in
}
func TestRegistrationSealsSecretsAndDoesNotExposeThem(t *testing.T) {
	box, _ := secretbox.New(make([]byte, 32))
	store := &storeSpy{}
	service := New(store, box, gateSpy{}, Config{Enabled: true, Origin: "https://chat.example.invalid", InstallationID: "33333333-3333-4333-8333-333333333333", Namespace: "staging", Now: func() time.Time { return time.Unix(1000, 0) }})
	in := webInput(t)
	result, err := service.Register(context.Background(), in)
	if err != nil {
		t.Fatal(err)
	}
	if result.Device.Generation != 1 || result.Device.State != "active" || store.calls != 1 {
		t.Fatal(result, store.calls)
	}
	raw, err := box.Open(store.record.SecretCipher, store.record.Scope())
	if err != nil || !strings.Contains(string(raw), in.Subscription.Endpoint) {
		t.Fatal("encrypted route unavailable")
	}
	public, _ := json.Marshal(result)
	for _, secret := range []string{in.Subscription.Endpoint, in.Subscription.Keys.Auth, "secret_cipher", "session_digest", "fingerprint"} {
		if strings.Contains(string(public), secret) {
			t.Fatal("private registration field exposed")
		}
	}
}
func TestUnavailableAndDeniedRegistrationDoNotWrite(t *testing.T) {
	store := &storeSpy{}
	service := New(store, nil, gateSpy{}, Config{Enabled: true})
	if _, err := service.Register(context.Background(), webInput(t)); err != ErrUnavailable {
		t.Fatal(err)
	}
	in := webInput(t)
	in.Permission = "denied"
	if err := Validate(in); err != ErrInvalid {
		t.Fatal(err)
	}
	if store.calls != 0 {
		t.Fatal("unavailable registration persisted")
	}
}
