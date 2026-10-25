package registerdevice

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"github.com/google/uuid"
	"net/url"
	"time"
	"voice-platform/backend/internal/notifications/secretbox"
)

type Store interface {
	Register(context.Context, Record, int64) (Record, error)
}
type EndpointValidator interface {
	Validate(context.Context, string) error
}
type Config struct {
	Enabled        bool
	Origin         string
	InstallationID string
	Namespace      string
	MobileReady    bool
	Lifetime       time.Duration
	Now            func() time.Time
}
type Service struct {
	store  Store
	box    *secretbox.Box
	gate   EndpointValidator
	config Config
}

func New(store Store, box *secretbox.Box, gate EndpointValidator, config Config) Service {
	if config.Now == nil {
		config.Now = time.Now
	}
	if config.Lifetime == 0 {
		config.Lifetime = 90 * 24 * time.Hour
	}
	return Service{store, box, gate, config}
}
func (s Service) Register(ctx context.Context, in Input) (Enrollment, error) {
	c := s.config
	origin, err := url.Parse(c.Origin)
	if !c.Enabled || s.box == nil || !validID(c.InstallationID) || c.Lifetime < 24*time.Hour || c.Lifetime > 180*24*time.Hour || err != nil || origin.Host == "" || origin.Path != "" || origin.User != nil || origin.RawQuery != "" || origin.Fragment != "" || (origin.Scheme != "https" && origin.Scheme != "http") {
		return Enrollment{}, ErrUnavailable
	}
	if err = Validate(in); err != nil {
		return Enrollment{}, err
	}
	if in.Namespace != c.Namespace {
		return Enrollment{}, ErrInvalid
	}
	now := c.Now().UTC()
	id := in.ID
	if id == "" {
		id = uuid.NewString()
	}
	record := Record{ID: id, InstanceID: in.InstanceID, Transport: in.Transport, Namespace: in.Namespace, Generation: in.ExpectedGeneration + 1, State: "active", Permission: in.Permission, ExpiresAt: now.Add(c.Lifetime), Origin: c.Origin, InstallationID: c.InstallationID, AccountID: in.AccountID, SessionDigest: in.SessionDigest, ConsentAt: now, CreatedAt: now, UpdatedAt: now}
	registration, _ := json.Marshal(in)
	record.RegistrationHash = sha256.Sum256(registration)
	nonce := ""
	if in.Transport == "web_push" {
		if s.gate == nil {
			return Enrollment{}, ErrUnavailable
		}
		if err = s.gate.Validate(ctx, in.Subscription.Endpoint); err != nil {
			return Enrollment{}, ErrInvalid
		}
		raw, err := json.Marshal(in.Subscription)
		if err != nil {
			return Enrollment{}, ErrInvalid
		}
		record.SecretCipher, err = s.box.Seal(raw, record.Scope())
		if err != nil {
			return Enrollment{}, ErrUnavailable
		}
		record.Fingerprint = sha256.Sum256([]byte(in.Subscription.Endpoint))
	} else {
		if !c.MobileReady {
			return Enrollment{}, ErrUnavailable
		}
		raw := make([]byte, 32)
		if _, err = rand.Read(raw); err != nil {
			return Enrollment{}, ErrUnavailable
		}
		nonce = base64.RawURLEncoding.EncodeToString(raw)
		digest := sha256.Sum256(raw)
		record.NonceDigest = digest[:]
		record.SecretCipher, err = s.box.Seal(raw, record.Scope())
		if err != nil {
			return Enrollment{}, ErrUnavailable
		}
		until := now.Add(5 * time.Minute)
		record.EnrollmentUntil = &until
		record.State = "registering"
		record.Fingerprint = sha256.Sum256([]byte("pending/" + id))
	}
	saved, err := s.store.Register(ctx, record, in.ExpectedGeneration)
	if err != nil {
		return Enrollment{}, err
	}
	saved.SessionRef = SessionReference(saved.SessionDigest)
	if in.Transport == "mobile_relay" {
		raw, err := s.box.Open(saved.SecretCipher, saved.Scope())
		if err != nil || len(raw) != 32 {
			return Enrollment{}, ErrUnavailable
		}
		nonce = base64.RawURLEncoding.EncodeToString(raw)
	}
	return Enrollment{Device: saved, Nonce: nonce}, nil
}
