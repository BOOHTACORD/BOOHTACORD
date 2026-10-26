package webpush

import (
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	sdk "github.com/SherClockHolmes/webpush-go"
	"io"
	"net/http"
	"net/http/httptrace"
	"strings"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	device "voice-platform/backend/internal/notifications/register_device"
)

type doFunc func(*http.Request) (*http.Response, error)

func (f doFunc) Do(r *http.Request) (*http.Response, error) { return f(r) }
func testMessage(t *testing.T) delivery.Message {
	t.Helper()
	key, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	sub := device.Subscription{Endpoint: "https://push.example.invalid/opaque"}
	sub.Keys.P256DH = base64.RawURLEncoding.EncodeToString(key.PublicKey().Bytes())
	sub.Keys.Auth = base64.RawURLEncoding.EncodeToString(make([]byte, 16))
	raw, _ := json.Marshal(sub)
	return delivery.Message{Secret: raw, Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: "11111111-1111-4111-8111-111111111111", NotificationRef: "22222222-2222-4222-8222-222222222222", GroupRef: "33333333-3333-4333-8333-333333333333", Template: "direct_message", ExpiresAt: time.Now().UTC().Add(time.Minute)}}
}
func TestSenderMapsDefinitiveResponsesWithoutInvalidatingAllDevices(t *testing.T) {
	private, public, err := sdk.GenerateVAPIDKeys()
	if err != nil {
		t.Fatal(err)
	}
	for code, want := range map[int]string{201: "accepted_by_provider", 404: "invalid_binding", 410: "invalid_binding", 429: "retry", 503: "retry", 401: "permanent_failure", 403: "permanent_failure", 302: "permanent_failure"} {
		t.Run(http.StatusText(code), func(t *testing.T) {
			sender := Sender{public: public, private: private, contact: "mailto:operator@example.invalid", client: doFunc(func(r *http.Request) (*http.Response, error) {
				body, _ := io.ReadAll(r.Body)
				if strings.Contains(string(body), "direct_message") || r.Header.Get("TTL") == "" || r.Header.Get("Topic") == "" {
					t.Fatal("unencrypted or unbounded request")
				}
				return &http.Response{StatusCode: code, Header: http.Header{"Retry-After": []string{"10"}}, Body: io.NopCloser(strings.NewReader("secret provider error"))}, nil
			})}
			result := sender.Send(context.Background(), testMessage(t))
			if result.Outcome != want {
				t.Fatal(result, want)
			}
			if (code == 401 || code == 403) && result.Reason != "configuration_error" {
				t.Fatal(result)
			}
		})
	}
}
func TestSenderTreatsWrittenRequestFailureAsAmbiguous(t *testing.T) {
	private, public, _ := sdk.GenerateVAPIDKeys()
	sender := Sender{public: public, private: private, contact: "mailto:operator@example.invalid", client: doFunc(func(r *http.Request) (*http.Response, error) {
		httptrace.ContextClientTrace(r.Context()).WroteRequest(httptrace.WroteRequestInfo{})
		return nil, context.DeadlineExceeded
	})}
	if got := sender.Send(context.Background(), testMessage(t)); got.Outcome != "delivery_unknown" {
		t.Fatal(got)
	}
}
