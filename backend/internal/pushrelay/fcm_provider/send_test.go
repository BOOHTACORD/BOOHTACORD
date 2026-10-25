package fcmprovider

import (
	"context"
	"encoding/json"
	"golang.org/x/oauth2"
	"io"
	"net/http"
	"net/http/httptrace"
	"strings"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
)

type doFunc func(*http.Request) (*http.Response, error)

func (f doFunc) Do(r *http.Request) (*http.Response, error) { return f(r) }
func message(t *testing.T, platform, kind string) Message {
	t.Helper()
	expires := time.Now().UTC().Add(time.Minute)
	payload, _ := json.Marshal(delivery.Payload{Version: 1, Generation: 1, BindingRef: "11111111-1111-4111-8111-111111111111", NotificationRef: "22222222-2222-4222-8222-222222222222", GroupRef: "33333333-3333-4333-8333-333333333333", Template: "direct_message", ExpiresAt: expires})
	return Message{TargetKind: kind, Target: "synthetic-provider-target", Platform: platform, Kind: "notification", Payload: payload, ExpiresAt: expires}
}
func TestPayloadHasExplicitTargetTypeNeutralTemplateAndOriginalExpiry(t *testing.T) {
	for _, platform := range []string{"android", "ios"} {
		for _, kind := range []string{"fcm_fid", "fcm_token"} {
			in := message(t, platform, kind)
			raw, err := Build(in, time.Now().UTC())
			if err != nil {
				t.Fatal(err)
			}
			var body map[string]map[string]any
			if json.Unmarshal(raw, &body) != nil {
				t.Fatal("invalid JSON")
			}
			m := body["message"]
			target := "fid"
			other := "token"
			if kind == "fcm_token" {
				target, other = other, target
			}
			if m[target] != in.Target || m[other] != nil || m["topic"] != nil || m["condition"] != nil {
				t.Fatal("ambiguous/broadcast target")
			}
			if m["notification"].(map[string]any)["body"] != "Новое личное сообщение" {
				t.Fatal("untrusted display template")
			}
			if platform == "android" {
				if m["android"] != nil || m["android_v2"].(map[string]any)["remote_notification"] == nil {
					t.Fatal("missing visible Android path")
				}
			}
			if platform == "ios" {
				headers := m["apns"].(map[string]any)["headers"].(map[string]any)
				if headers["apns-push-type"] != "alert" || headers["apns-expiration"] == nil {
					t.Fatal("missing APNs expiry")
				}
				if strings.Contains(string(raw), `"badge"`) {
					t.Fatal("fabricated unread badge")
				}
			}
		}
	}
}
func TestProviderDistinguishesTokenRevokeFromProjectOrPayloadFault(t *testing.T) {
	for _, tc := range []struct {
		code       int
		body, want string
	}{{200, `{}`, "accepted_by_provider"}, {404, `{"error":{"details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}`, "invalid_binding"}, {404, `{"error":{"status":"NOT_FOUND"}}`, "permanent_failure"}, {400, `{"error":{"status":"INVALID_ARGUMENT"}}`, "permanent_failure"}, {401, `{}`, "permanent_failure"}, {403, `{}`, "permanent_failure"}, {429, `{}`, "retry"}, {503, `{}`, "retry"}} {
		sender := Sender{project: "synthetic-project", tokens: oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "synthetic-test-only"}), client: doFunc(func(r *http.Request) (*http.Response, error) {
			if r.URL.Host != "fcm.googleapis.com" || r.URL.Path != "/v1/projects/synthetic-project/messages:send" {
				t.Fatal("variable provider host")
			}
			return &http.Response{StatusCode: tc.code, Body: io.NopCloser(strings.NewReader(tc.body)), Header: make(http.Header)}, nil
		})}
		if got := sender.Send(context.Background(), message(t, "android", "fcm_fid")); got.Outcome != tc.want {
			t.Fatal(tc.code, got)
		}
	}
}
func TestProviderDoesNotBlindlyRetryAnAcceptedUnknownWrite(t *testing.T) {
	sender := Sender{project: "synthetic-project", tokens: oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "synthetic-test-only"}), client: doFunc(func(r *http.Request) (*http.Response, error) {
		httptrace.ContextClientTrace(r.Context()).WroteRequest(httptrace.WroteRequestInfo{})
		return nil, context.DeadlineExceeded
	})}
	if got := sender.Send(context.Background(), message(t, "ios", "fcm_fid")); got.Outcome != "delivery_unknown" {
		t.Fatal(got)
	}
}
