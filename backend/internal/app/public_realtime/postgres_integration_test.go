package publicrealtime

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	maintenance "voice-platform/backend/internal/maintenance/admission"
	maintenancepostgres "voice-platform/backend/internal/maintenance/admission/postgres"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestPublicSocketDetectsIndependentDatabaseChange(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if _, err := pool.Exec(ctx, `CREATE TABLE maintenance_admission (singleton boolean PRIMARY KEY, active boolean NOT NULL, changed_at timestamptz NOT NULL DEFAULT now()); INSERT INTO maintenance_admission(singleton, active) VALUES (true, false)`); err != nil {
		t.Fatal(err)
	}
	service := maintenance.New(maintenancepostgres.New(maintenancepostgres.NewPoolDatabase(pool)))
	handler, stop, err := Start(ctx, service, "https://example.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	server := httptest.NewServer(handler)
	defer server.Close()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
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
	if err := wsjson.Read(ctx, socket, &event); err != nil || event.Kind != "maintenance.snapshot" || event.Payload["active"] != false {
		t.Fatalf("snapshot: %+v, %v", event, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE maintenance_admission SET active=true WHERE singleton=true`); err != nil {
		t.Fatal(err)
	}
	readContext, stopRead := context.WithTimeout(ctx, 7*time.Second)
	defer stopRead()
	if err := wsjson.Read(readContext, socket, &event); err != nil || event.Kind != "maintenance.changed" || event.Payload["active"] != true {
		t.Fatalf("change: %+v, %v", event, err)
	}
}
