package webpush

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	sdk "github.com/SherClockHolmes/webpush-go"
	"io"
	"net/http"
	"net/http/httptrace"
	"strconv"
	"sync/atomic"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
)

type httpClient interface {
	Do(*http.Request) (*http.Response, error)
}
type Sender struct {
	client                   httpClient
	public, private, contact string
}

func NewSender(gate Gate, public, private, contact string) (Sender, error) {
	if err := ValidateVAPID(public, private, contact); err != nil {
		return Sender{}, err
	}
	return Sender{NewHTTPClient(gate), public, private, contact}, nil
}
func (s Sender) Send(ctx context.Context, message delivery.Message) delivery.Result {
	failure := func(outcome, reason string) delivery.Result { return delivery.Result{Outcome: outcome, Reason: reason} }
	now := time.Now().UTC()
	if message.Payload.Validate(now) != nil || len(message.Secret) > 16384 {
		return failure("permanent_failure", "invalid")
	}
	ttl := int(message.Payload.ExpiresAt.Sub(now) / time.Second)
	if ttl < 1 {
		return failure("permanent_failure", "expired")
	}
	var subscription sdk.Subscription
	if json.Unmarshal(message.Secret, &subscription) != nil || subscription.Endpoint == "" {
		return failure("permanent_failure", "configuration_error")
	}
	raw, err := json.Marshal(message.Payload)
	if err != nil {
		return failure("permanent_failure", "invalid")
	}
	hash := sha256.Sum256([]byte(message.Payload.GroupRef))
	topic := base64.RawURLEncoding.EncodeToString(hash[:24])
	var wrote atomic.Bool
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	ctx = httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote.Store(true) }})
	response, err := sdk.SendNotificationWithContext(ctx, raw, &subscription, &sdk.Options{HTTPClient: s.client, Subscriber: s.contact, VAPIDPublicKey: s.public, VAPIDPrivateKey: s.private, TTL: ttl, Topic: topic, Urgency: sdk.UrgencyNormal})
	if err != nil {
		if wrote.Load() {
			return failure("delivery_unknown", "transport_unknown")
		}
		return failure("retry", "provider_error")
	}
	if response == nil {
		return failure("delivery_unknown", "transport_unknown")
	}
	if response.Body != nil {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 4096))
		_ = response.Body.Close()
	}
	switch {
	case response.StatusCode >= 200 && response.StatusCode < 300:
		return failure("accepted_by_provider", "none")
	case response.StatusCode == 404 || response.StatusCode == 410:
		return failure("invalid_binding", "invalid_binding")
	case response.StatusCode == 401 || response.StatusCode == 403:
		return failure("permanent_failure", "configuration_error")
	case response.StatusCode == 429 || response.StatusCode >= 500:
		return delivery.Result{Outcome: "retry", Reason: "provider_error", RetryAfter: retryAfter(response.Header.Get("Retry-After"), now)}
	default:
		return failure("permanent_failure", "provider_error")
	}
}
func retryAfter(value string, now time.Time) time.Duration {
	if len(value) > 128 {
		return 0
	}
	if seconds, err := strconv.Atoi(value); err == nil && seconds > 0 {
		return time.Duration(min(seconds, 86400)) * time.Second
	}
	if date, err := http.ParseTime(value); err == nil && date.After(now) {
		return min(date.Sub(now), 24*time.Hour)
	}
	return 0
}
