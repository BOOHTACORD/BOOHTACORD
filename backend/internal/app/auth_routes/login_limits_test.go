package authroutes

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
)

func TestLoginBudgetsRouteComposition(t *testing.T) {
	values := map[string]string{"PUBLIC_ORIGIN": "https://example.test", "ATTACHMENTS_DIRECTORY": "/attachments", "LIVEKIT_PUBLIC_WS_URL": "wss://example.test", "LIVEKIT_PRIVATE_HTTP_URL": "http://livekit:7880", "LIVEKIT_API_KEY": "test-key", "LIVEKIT_API_SECRET": "test-secret"}
	configuration, err := runtimeconfig.Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	var called int
	handler := loginLimits(configuration, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { called++; w.WriteHeader(http.StatusNoContent) }))
	request := func(source string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", nil)
		r.RemoteAddr = source + ":1234"
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		return w
	}
	for n := 0; n < 32; n++ {
		if response := request("192.0.2.1"); response.Code != 204 {
			t.Fatalf("same-source attempt %d: %d", n+1, response.Code)
		}
	}
	if response := request("192.0.2.1"); response.Code != 429 || response.Header().Get("Retry-After") == "" {
		t.Fatal("source budget did not refuse attempt 33")
	}
	for n := 0; n < 168; n++ {
		if response := request(fmt.Sprintf("198.51.100.%d", n+1)); response.Code != 204 {
			t.Fatalf("deployment attempt %d: %d", n+33, response.Code)
		}
	}
	if response := request("203.0.113.1"); response.Code != 429 || response.Header().Get("Retry-After") == "" || called != 200 {
		t.Fatal("deployment budget did not stop work at 200")
	}
}
