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
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func TestSaturatedSecurityOverflowClosesRealSocket(t *testing.T) {
	hub := eventhub.New(1)
	sub := hub.SubscribeAccountWithCapabilities("owner", eventhub.Event{}, []string{"role_permissions_v1"})
	defer sub.Close()
	hub.PublishToAccounts([]string{"owner"}, eventhub.Event{EventID: "a", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, eventhub.Event{EventID: "b", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, eventhub.Event{EventID: "c", Kind: "session.state_changed"})
	hub.PublishToAccounts([]string{"owner"}, eventhub.Event{EventID: "d", Kind: "auth.permissions.invalidated"})
	finished := make(chan bool, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		socket, err := websocket.Accept(w, r, nil)
		if err != nil {
			finished <- true
			return
		}
		defer socket.CloseNow()
		now, newID := connectionDefaults(time.Now, nil)
		finished <- writeOverflow(socket, sub, hub, newID, now)
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	client, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer client.CloseNow()
	for i := 0; i < 2; i++ {
		var event Event
		if err := wsjson.Read(ctx, client, &event); err != nil {
			t.Fatal(err)
		}
	}
	_, _, err = client.Read(ctx)
	if websocket.CloseStatus(err) != websocket.StatusTryAgainLater {
		t.Fatalf("wrong close status: %v", err)
	}
	if <-finished {
		t.Fatal("saturated socket remained open")
	}
}
