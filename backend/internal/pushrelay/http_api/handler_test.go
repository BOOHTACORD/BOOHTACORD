package relayapi

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestPublicEnrollmentNeverReturnsChallengeOrProviderAddress(t *testing.T) {
	pool := fixture.New(t)
	public, _, _ := ed25519.GenerateKey(rand.Reader)
	h := Handler{Ready: true, Enroll: enroll.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}}
	raw, _ := json.Marshal(enroll.Challenge{TargetKind: "fcm_fid", Target: "synthetic-firebase-installation-id", PublicKey: base64.RawURLEncoding.EncodeToString(public), Platform: "android", Namespace: "staging"})
	request := httptest.NewRequest("POST", "/v1/devices/challenge", strings.NewReader(string(raw)))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	h.Routes().ServeHTTP(response, request)
	if response.Code != 202 || strings.Contains(response.Body.String(), "nonce") || strings.Contains(response.Body.String(), "synthetic-firebase") {
		t.Fatal(response.Code, response.Body.String())
	}
	var devices int
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM relay_devices`).Scan(&devices); err != nil || devices != 1 {
		t.Fatal(devices, err)
	}
	for _, body := range []string{`{"target":"address","account_id":"victim"}`, strings.Repeat("x", 17000), `{} {}`} {
		request = httptest.NewRequest("POST", "/v1/devices/challenge", strings.NewReader(body))
		request.Header.Set("Content-Type", "application/json")
		response = httptest.NewRecorder()
		h.Routes().ServeHTTP(response, request)
		if response.Code != 400 {
			t.Fatal("unbounded/unknown request accepted", response.Code)
		}
	}
	request = httptest.NewRequest("POST", "/v1/devices/challenge", strings.NewReader(string(raw)))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Origin", "https://malicious.invalid")
	response = httptest.NewRecorder()
	h.Routes().ServeHTTP(response, request)
	if response.Code != 403 {
		t.Fatal("browser caller bypassed device proof boundary", response.Code)
	}
}
func TestMissingProviderIsUnavailableAndCoreHealthRemainsHonest(t *testing.T) {
	h := Handler{Ready: false}
	mux := h.Routes()
	request := httptest.NewRequest("POST", "/v1/devices/challenge", strings.NewReader(`{}`))
	response := httptest.NewRecorder()
	mux.ServeHTTP(response, request)
	if response.Code != 503 {
		t.Fatal(response.Code)
	}
	response = httptest.NewRecorder()
	mux.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/health", nil))
	if response.Code != 200 || !strings.Contains(response.Body.String(), `"provider_available":false`) {
		t.Fatal(response.Code, response.Body.String())
	}
}
