package fcmprovider

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptrace"
	"strconv"
	"sync/atomic"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
)

func (s *Sender) Send(ctx context.Context, in Message) delivery.Result {
	result := func(outcome, reason string) delivery.Result { return delivery.Result{Outcome: outcome, Reason: reason} }
	now := time.Now().UTC()
	raw, err := Build(in, now)
	if err != nil {
		return result("permanent_failure", "invalid")
	}
	if s == nil || s.tokens == nil || s.client == nil || !projectPattern.MatchString(s.project) {
		return result("permanent_failure", "configuration_error")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	token, err := s.tokens.Token()
	if err != nil {
		return result("retry", "configuration_error")
	}
	request, err := http.NewRequestWithContext(ctx, "POST", "https://fcm.googleapis.com/v1/projects/"+s.project+"/messages:send", bytes.NewReader(raw))
	if err != nil {
		return result("permanent_failure", "configuration_error")
	}
	request.Header.Set("Authorization", "Bearer "+token.AccessToken)
	request.Header.Set("Content-Type", "application/json")
	var wrote atomic.Bool
	request = request.WithContext(httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote.Store(true) }}))
	response, err := s.client.Do(request)
	if err != nil {
		if wrote.Load() {
			return result("delivery_unknown", "transport_unknown")
		}
		return result("retry", "provider_error")
	}
	if response == nil {
		return result("delivery_unknown", "transport_unknown")
	}
	var body []byte
	if response.Body != nil {
		body, _ = io.ReadAll(io.LimitReader(response.Body, 16384))
		_ = response.Body.Close()
	}
	if response.StatusCode >= 200 && response.StatusCode < 300 {
		return result("accepted_by_provider", "none")
	}
	var fault struct {
		Error struct {
			Details []struct {
				Type string `json:"@type"`
				Code string `json:"errorCode"`
			} `json:"details"`
		} `json:"error"`
	}
	_ = json.Unmarshal(body, &fault)
	for _, detail := range fault.Error.Details {
		if response.StatusCode == 404 && detail.Type == "type.googleapis.com/google.firebase.fcm.v1.FcmError" && detail.Code == "UNREGISTERED" {
			return result("invalid_binding", "invalid_binding")
		}
	}
	if response.StatusCode == 401 || response.StatusCode == 403 || response.StatusCode == 404 {
		return result("permanent_failure", "configuration_error")
	}
	if response.StatusCode == 429 || response.StatusCode >= 500 {
		after := time.Duration(0)
		if seconds, err := strconv.Atoi(response.Header.Get("Retry-After")); err == nil && seconds > 0 {
			after = time.Duration(min(seconds, 3600)) * time.Second
		} else if date, err := http.ParseTime(response.Header.Get("Retry-After")); err == nil && date.After(now) {
			after = min(date.Sub(now), time.Hour)
		}
		return delivery.Result{Outcome: "retry", Reason: "provider_error", RetryAfter: after}
	}
	return result("permanent_failure", "provider_error")
}
