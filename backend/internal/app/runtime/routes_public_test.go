//go:build linux

package app

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	publicrealtime "voice-platform/backend/internal/app/public_realtime"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	previewmemory "voice-platform/backend/internal/media/screen_preview/memory"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type publicReader struct{}

func (publicReader) Active(context.Context) (bool, error) { return true, nil }

func TestComposedPublicRealtimeRouteDoesNotRequireSession(t *testing.T) {
	values := map[string]string{"PUBLIC_ORIGIN": "https://example.test", "ATTACHMENTS_DIRECTORY": t.TempDir(), "SCREEN_PREVIEW_DIRECTORY": t.TempDir(),
		"LIVEKIT_PUBLIC_WS_URL": "wss://example.test", "LIVEKIT_PRIVATE_HTTP_URL": "http://livekit:7880", "LIVEKIT_API_KEY": "test-key", "LIVEKIT_API_SECRET": "test-secret"}
	config, err := runtimeconfig.Load(func(key string) string { return values[key] })
	if err != nil {
		t.Fatal(err)
	}
	previews := previewmemory.New()
	defer previews.Close()
	viewers := presencememory.New(nil)
	defer viewers.Close()
	public, stop, err := publicrealtime.Start(context.Background(), publicReader{}, values["PUBLIC_ORIGIN"], nil)
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	handler, _, err := routes(nil, config, eventhub.New(64), httpmetrics.New(), unavailableUpdates{}, nil, previews, viewers, public, nil)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/public/realtime", &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {values["PUBLIC_ORIGIN"]}}})
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	var event struct {
		Kind    string         `json:"kind"`
		Payload map[string]any `json:"payload"`
	}
	if err := wsjson.Read(ctx, socket, &event); err != nil || event.Kind != "connection.ready" {
		t.Fatalf("ready: %+v, %v", event, err)
	}
	if err := wsjson.Read(ctx, socket, &event); err != nil || event.Kind != "maintenance.snapshot" || event.Payload["active"] != true {
		t.Fatalf("snapshot: %+v, %v", event, err)
	}
}
