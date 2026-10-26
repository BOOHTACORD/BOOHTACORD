package testscenario

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	p "voice-platform/backend/internal/notifications/preferences"
	prefstore "voice-platform/backend/internal/notifications/preferences/postgres"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	d "voice-platform/backend/internal/notifications/register_device"
	store "voice-platform/backend/internal/notifications/register_device/postgres"
	"voice-platform/backend/internal/notifications/secretbox"
	"voice-platform/backend/internal/observability/installation"
)

type endpointFixture struct{}

func (endpointFixture) Validate(context.Context, string) error { return nil }
func Box(t testing.TB) *secretbox.Box {
	t.Helper()
	box, err := secretbox.New(make([]byte, 32))
	if err != nil {
		t.Fatal(err)
	}
	return box
}
func Scope(t testing.TB, pool *pgxpool.Pool) reader.Scope {
	t.Helper()
	identity, err := installation.Load(context.Background(), pool)
	if err != nil {
		t.Fatal(err)
	}
	return reader.Scope{Origin: "https://chat.example.invalid", InstallationID: identity.ID, Namespace: "staging"}
}
func Enable(t testing.TB, pool *pgxpool.Pool, account string, textMode p.Mode) {
	t.Helper()
	settings := p.Default()
	settings.Enabled = true
	settings.Text.Mode = textMode
	if _, err := prefstore.New(pool).Save(context.Background(), p.Input{AccountID: account, Settings: settings}); err != nil {
		t.Fatal(err)
	}
}
func AddDevice(t testing.TB, pool *pgxpool.Pool, account string) d.Record {
	t.Helper()
	scope := Scope(t, pool)
	digest := [32]byte{2}
	if account == Author {
		digest = [32]byte{1}
	} else if account == Outsider {
		digest = [32]byte{3}
	}
	private, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	sub := &d.Subscription{Endpoint: "https://push.example.invalid/" + uuid.NewString()}
	sub.Keys.P256DH = base64.RawURLEncoding.EncodeToString(private.PublicKey().Bytes())
	sub.Keys.Auth = base64.RawURLEncoding.EncodeToString(make([]byte, 16))
	service := d.New(store.New(pool), Box(t), endpointFixture{}, d.Config{Enabled: true, Origin: scope.Origin, InstallationID: scope.InstallationID, Namespace: scope.Namespace, Now: func() time.Time { return time.Now().Add(-time.Minute) }})
	result, err := service.Register(context.Background(), d.Input{AccountID: account, SessionDigest: digest, InstanceID: uuid.NewString(), Transport: "web_push", Namespace: "staging", ConsentVersion: 1, Permission: "granted", Subscription: sub})
	if err != nil {
		t.Fatal(err)
	}
	return result.Device
}
