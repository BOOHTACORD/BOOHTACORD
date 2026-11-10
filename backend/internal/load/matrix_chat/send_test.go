package matrixchat

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSendSyntheticMessageOnlyToLoopbackFixture(t *testing.T) {
	channel := "11111111-1111-4111-8111-111111111111"
	message := "22222222-2222-4222-8222-222222222222"
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" || r.URL.Path != "/api/v1/channels/"+channel+"/messages" || r.Header.Get("Origin") == "" {
			t.Error("unexpected fixture request")
		}
		var body map[string]string
		if json.NewDecoder(r.Body).Decode(&body) != nil || body["body"] != "synthetic load message" || body["client_message_id"] == "" {
			t.Error("invalid synthetic body")
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]string{"id": message})
	}))
	defer server.Close()
	got, err := Send(context.Background(), server.Client(), server.URL, channel)
	if err != nil || got != message {
		t.Fatalf("send: %q %v", got, err)
	}
	if _, err := Send(context.Background(), server.Client(), "https://example.com:443", channel); err == nil {
		t.Fatal("non-loopback target accepted")
	}
	if _, err := Send(context.Background(), server.Client(), server.URL, "not-a-uuid"); err == nil {
		t.Fatal("invalid channel accepted")
	}
}

func TestSendExposesOnlySafeHTTPStatusOnFailure(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = w.Write([]byte("private fixture content"))
	}))
	defer server.Close()
	_, err := Send(context.Background(), server.Client(), server.URL, "11111111-1111-4111-8111-111111111111")
	var failure *ReceiptError
	if !errors.As(err, &failure) || failure.StatusCode != http.StatusTooManyRequests || strings.Contains(err.Error(), "private") {
		t.Fatal("safe status missing or response body exposed")
	}
}
