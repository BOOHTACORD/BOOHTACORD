package relaysender

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

func (s Sender) Send(ctx context.Context, in delivery.Message) delivery.Result {
	fail := func(outcome, reason string) delivery.Result { return delivery.Result{Outcome: outcome, Reason: reason} }
	if in.Payload.Validate(time.Now().UTC()) != nil || len(in.Secret) > 16384 {
		return fail("permanent_failure", "invalid")
	}
	var signed receipt.Receipt
	if json.Unmarshal(in.Secret, &signed) != nil {
		return fail("permanent_failure", "configuration_error")
	}
	grant, err := receipt.Verify(s.config.RelayPublicKey, signed, time.Now().UTC())
	if err != nil {
		return fail("permanent_failure", "configuration_error")
	}
	if len(s.config.InstallationPrivateKey) != ed25519.PrivateKeySize {
		return fail("permanent_failure", "configuration_error")
	}
	public := base64.RawURLEncoding.EncodeToString(s.config.InstallationPrivateKey.Public().(ed25519.PublicKey))
	if grant.Origin != s.config.ServerOrigin || grant.InstallationID != s.config.InstallationID || grant.InstallationPublicKey != public || grant.Namespace != s.config.Namespace || grant.BindingID != in.Payload.BindingRef || grant.Generation != in.Payload.Generation {
		return fail("permanent_failure", "configuration_error")
	}
	if !in.OccurredAt.IsZero() && in.Payload.ExpiresAt.After(in.OccurredAt.Add(time.Hour)) {
		in.Payload.ExpiresAt = in.OccurredAt.Add(time.Hour)
	}
	if !in.Payload.ExpiresAt.After(time.Now().UTC()) {
		return fail("permanent_failure", "expired")
	}
	result, err := s.post(ctx, "/v1/notifications", grant.TenantID, accept.Input{GrantID: grant.GrantID, Payload: in.Payload})
	if err == nil && (result.Code == 200 || result.Code == 202) {
		return resultStatus(result, in.Payload.NotificationRef)
	}
	if err == nil && result.Code == 404 && result.Error == "ROUTE_UNAVAILABLE" {
		return fail("invalid_binding", "invalid_binding")
	}
	if err == nil && (result.Code == 401 || result.Code == 403 || result.Code >= 300 && result.Code < 400) {
		return fail("permanent_failure", "configuration_error")
	}
	if err == nil && result.Code == 429 {
		return delivery.Result{Outcome: "retry", Reason: "provider_error", RetryAfter: time.Minute}
	}
	if result.Written || result.Code >= 500 || result.Code == 200 || result.Code == 202 {
		known, pollErr := s.post(ctx, "/v1/receipts", grant.TenantID, accept.Query{GrantID: grant.GrantID, JobRef: in.Payload.NotificationRef})
		if pollErr == nil && known.Code == 200 {
			return resultStatus(known, in.Payload.NotificationRef)
		}
		if pollErr == nil && known.Code == 404 && known.Error == "NOT_FOUND" {
			return fail("retry", "provider_error")
		}
		if pollErr == nil && known.Code == 404 && known.Error == "ROUTE_UNAVAILABLE" {
			return fail("invalid_binding", "invalid_binding")
		}
		return fail("delivery_unknown", "transport_unknown")
	}
	if err != nil {
		return fail("retry", "provider_error")
	}
	return fail("permanent_failure", "provider_error")
}
func resultStatus(r response, expected string) delivery.Result {
	if r.Status.Version != 1 || r.Status.JobRef != expected {
		return delivery.Result{Outcome: "delivery_unknown", Reason: "transport_unknown"}
	}
	switch r.Status.State {
	case "accepted_by_relay", "accepted_by_provider":
		return delivery.Result{Outcome: r.Status.State, Reason: "none"}
	case "delivery_unknown":
		return delivery.Result{Outcome: "delivery_unknown", Reason: "transport_unknown"}
	case "revoked":
		return delivery.Result{Outcome: "invalid_binding", Reason: "invalid_binding"}
	case "expired":
		return delivery.Result{Outcome: "permanent_failure", Reason: "expired"}
	case "permanent_failure":
		return delivery.Result{Outcome: "permanent_failure", Reason: "provider_error"}
	default:
		return delivery.Result{Outcome: "delivery_unknown", Reason: "transport_unknown"}
	}
}
