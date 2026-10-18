//go:build linux

package app

import (
	_ "embed"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	previewmemory "voice-platform/backend/internal/media/screen_preview/memory"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

//go:embed testdata/protected_routes.json
var protectedRoutes []byte

func TestComposedRoutesPreserveSessionAndOriginBoundaries(t *testing.T) {
	values := map[string]string{"PUBLIC_ORIGIN": "https://example.test", "ATTACHMENTS_DIRECTORY": t.TempDir(),
		"LIVEKIT_PUBLIC_WS_URL": "wss://example.test", "LIVEKIT_PRIVATE_HTTP_URL": "http://livekit:7880",
		"LIVEKIT_API_KEY": "test-key", "LIVEKIT_API_SECRET": "test-secret"}
	configuration, err := runtimeconfig.Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	previews := previewmemory.New()
	defer previews.Close()
	screenViewers := presencememory.New(nil)
	defer screenViewers.Close()
	handler, err := routes(nil, configuration, eventhub.New(64), httpmetrics.New(), unavailableUpdates{}, nil, previews, screenViewers)
	if err != nil {
		t.Fatal(err)
	}
	var preserved []string
	if err := json.Unmarshal(protectedRoutes, &preserved); err != nil {
		t.Fatal(err)
	}
	for _, route := range preserved {
		t.Run(route, func(t *testing.T) {
			method, path, _ := strings.Cut(route, " ")
			request := httptest.NewRequest(method, path, nil)
			request.Header.Set("Origin", values["PUBLIC_ORIGIN"])
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != http.StatusUnauthorized {
				t.Fatalf("got %d, expected session boundary", response.Code)
			}
		})
	}
	request := httptest.NewRequest(http.MethodPost, "/api/v1/voice/channels/channel/leases", nil)
	request.Header.Set("Origin", "https://foreign.test")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusForbidden {
		t.Fatalf("foreign origin got %d", response.Code)
	}
}

type unavailableUpdates struct{}

func (unavailableUpdates) Policy(clientupdates.Selector) (clientupdates.Policy, bool) {
	return clientupdates.Policy{}, false
}
