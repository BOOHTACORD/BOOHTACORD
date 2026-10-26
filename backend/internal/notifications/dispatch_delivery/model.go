package dispatchdelivery

import (
	"context"
	"errors"
	"regexp"
	"time"
)

type Payload struct {
	Version         int       `json:"version"`
	Generation      int64     `json:"generation"`
	BindingRef      string    `json:"binding_ref"`
	NotificationRef string    `json:"notification_ref"`
	GroupRef        string    `json:"group_ref"`
	Template        string    `json:"template"`
	ExpiresAt       time.Time `json:"expires_at"`
}
type Message struct {
	Payload    Payload
	Secret     []byte
	Transport  string
	OccurredAt time.Time
}
type Result struct {
	Outcome    string
	Reason     string
	RetryAfter time.Duration
}
type Transport interface {
	Send(context.Context, Message) Result
}

var ErrInvalidPayload = errors.New("invalid notification payload")
var opaqueReference = regexp.MustCompile(`^[A-Za-z0-9_-]{16,128}$`)

func (p Payload) Validate(now time.Time) error {
	if p.Version != 1 || p.Generation < 1 || p.Generation > 1000000000 || !opaqueReference.MatchString(p.BindingRef) || !opaqueReference.MatchString(p.NotificationRef) || !opaqueReference.MatchString(p.GroupRef) {
		return ErrInvalidPayload
	}
	if p.Template != "direct_message" && p.Template != "mention" && p.Template != "activity" {
		return ErrInvalidPayload
	}
	_, offset := p.ExpiresAt.Zone()
	if offset != 0 || !p.ExpiresAt.After(now) || p.ExpiresAt.After(now.Add(24*time.Hour)) {
		return ErrInvalidPayload
	}
	return nil
}
