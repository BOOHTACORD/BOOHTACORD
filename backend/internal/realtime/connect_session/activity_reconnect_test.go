package connectsession

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestConfirmedActivitySocketKeepsIdleUntilAuthenticatedActivity(t *testing.T) {
	hub := eventhub.New(8)
	old := hub.SubscribeAccountAt("user-1", eventhub.Event{}, time.Now().Add(-6*time.Minute))
	defer old.Close()
	hub.SweepIdle(time.Now(), eventhub.DefaultIdleAfter)
	handler := NewHandlerWithEvents(nil, time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	url := "ws" + strings.TrimPrefix(server.URL, "http") + "?capabilities=confirmed_activity_v1"
	connection, _, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	var ready, snapshot Event
	if err := wsjson.Read(ctx, connection, &ready); err != nil || ready.Kind != "connection.ready" {
		t.Fatalf("ready: %#v, %v", ready, err)
	}
	if err := wsjson.Read(ctx, connection, &snapshot); err != nil || snapshot.Kind != "presence.snapshot" {
		t.Fatalf("snapshot: %#v, %v", snapshot, err)
	}
	ids, ok := snapshot.Payload["idle_user_ids"].([]any)
	if !ok || len(ids) != 1 || ids[0] != "user-1" {
		t.Fatalf("idle snapshot: %#v", snapshot.Payload)
	}
	if err := wsjson.Write(ctx, connection, map[string]string{"type": "inactive"}); err != nil {
		t.Fatal(err)
	}
	for {
		if _, ok := hub.LastActivity("user-1"); ok {
			break
		}
		select {
		case <-ctx.Done():
			t.Fatal("confirmed inactivity was not received")
		case <-time.After(time.Millisecond):
		}
	}
	if state := hub.PresenceState("user-1"); state != "idle" {
		t.Fatalf("inactivity revived state: %q", state)
	}
	if err := wsjson.Write(ctx, connection, map[string]string{"type": "activity"}); err != nil {
		t.Fatal(err)
	}
	var active Event
	if err := wsjson.Read(ctx, connection, &active); err != nil || active.Kind != "presence.changed" || active.Payload["activity_state"] != "active" {
		t.Fatalf("activity transition: %#v, %v", active, err)
	}
}

func TestFreshServerUsesInitialIdleCapabilityInSnapshot(t *testing.T) {
	hub := eventhub.New(8)
	handler := NewHandlerWithEvents(nil, time.Hour, time.Now, nil, nil, hub)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "user-1"})))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	url := "ws" + strings.TrimPrefix(server.URL, "http") + "?capabilities=confirmed_activity_v1,initial_idle_v1"
	connection, _, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": {server.URL}}})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	var ready, snapshot Event
	if err := wsjson.Read(ctx, connection, &ready); err != nil || ready.Kind != "connection.ready" {
		t.Fatalf("ready: %#v, %v", ready, err)
	}
	if err := wsjson.Read(ctx, connection, &snapshot); err != nil || snapshot.Kind != "presence.snapshot" {
		t.Fatalf("snapshot: %#v, %v", snapshot, err)
	}
	ids, ok := snapshot.Payload["idle_user_ids"].([]any)
	if !ok || len(ids) != 1 || ids[0] != "user-1" {
		t.Fatalf("idle snapshot: %#v", snapshot.Payload)
	}
}
