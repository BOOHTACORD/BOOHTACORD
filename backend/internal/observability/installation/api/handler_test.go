package installationapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	central "voice-platform/backend/internal/observability/central_export"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestPublicIdentityAndAdminStateNeverReturnSecrets(t *testing.T) {
	i, _ := identity.New()
	i.Credential = "private-credential"
	i.Endpoint = "https://private.example.test"
	h := Handler{Runtime: central.New(i, nil, nil)}
	for _, read := range []func(http.ResponseWriter, *http.Request){h.Public, h.Read} {
		w := httptest.NewRecorder()
		read(w, httptest.NewRequest("GET", "/", nil))
		if w.Code != 200 || strings.Contains(w.Body.String(), "private-") || bytes.Contains(w.Body.Bytes(), i.Key) {
			t.Fatal("secret in public state")
		}
		var body map[string]any
		if json.Unmarshal(w.Body.Bytes(), &body) != nil || body["installation_id"] != i.ID {
			t.Fatal("identity absent")
		}
	}
}
func TestExternalEnrollmentRequiresExplicitConsent(t *testing.T) {
	i, _ := identity.New()
	h := Handler{Runtime: central.New(i, nil, nil)}
	for _, body := range []string{`{"mode":"central","endpoint":"https://example.test"}`, `{"mode":"central","confirmed":true,"endpoint":"http://127.0.0.1"}`, `{"mode":"local_only","credential":"forged"}`} {
		w := httptest.NewRecorder()
		h.Patch(w, httptest.NewRequest("PATCH", "/", strings.NewReader(body)))
		if w.Code != 400 {
			t.Fatalf("invalid settings status %d", w.Code)
		}
	}
}
