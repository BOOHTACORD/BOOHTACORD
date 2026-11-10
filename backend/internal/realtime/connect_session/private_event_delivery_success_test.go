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

type deliveryObserver struct {
	latencies chan time.Duration
	stages    chan [2]time.Duration
}

func (deliveryObserver) RealtimeConnectionOpened()                    {}
func (deliveryObserver) ObserveRealtimeConnectionReady(time.Duration) {}
func (deliveryObserver) RealtimeConnectionClosed()                    {}
func (observer deliveryObserver) ObserveRealtimeEventDeliveryLatency(latency time.Duration) {
	observer.latencies <- latency
}

func (observer deliveryObserver) ObserveRealtimeEventStages(queue, write time.Duration) {
	if observer.stages != nil {
		observer.stages <- [2]time.Duration{queue, write}
	}
}

func TestCurrentSessionReceivesPrivateDirectMessageHint(t *testing.T) {
	hub := eventhub.New(4)
	observer := deliveryObserver{latencies: make(chan time.Duration, 4), stages: make(chan [2]time.Duration, 4)}
	handler := NewHandlerWithEvents(authenticatorFunc(func(_ context.Context, token string) (auth.Principal, error) {
		if token != "opaque-token" {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return auth.Principal{AccountID: "member"}, nil
	}), time.Hour, time.Now, nil, observer, hub)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		handler.ServeHTTP(writer, request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	connection, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: http.Header{
		"Cookie": {"vp_session=opaque-token"}, "Origin": {server.URL},
	}})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	for range 3 {
		var initial Event
		if err := wsjson.Read(context.Background(), connection, &initial); err != nil {
			t.Fatal(err)
		}
	}
	hub.PublishToAccounts([]string{"member"}, eventhub.Event{EventID: "private", Kind: "direct_message.message_created", OccurredAt: time.Now().Add(-10 * time.Millisecond), Payload: map[string]any{"direct_message_id": "pair", "message_id": "message"}})
	readContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	var event Event
	if err := wsjson.Read(readContext, connection, &event); err != nil || event.Kind != "direct_message.message_created" || len(event.Payload) != 2 || event.Payload["message_id"] != "message" {
		t.Fatalf("private event=%#v err=%v", event, err)
	}
	deadline := time.After(time.Second)
	for {
		select {
		case stages := <-observer.stages:
			if stages[0] < 0 || stages[1] < 0 {
				t.Fatalf("invalid stages: %v", stages)
			}
			if stages[0] >= 5*time.Millisecond {
				for {
					select {
					case latency := <-observer.latencies:
						if latency > 0 {
							return
						}
					case <-deadline:
						t.Fatal("successful event write did not report delivery latency")
					}
				}
			}
		case <-deadline:
			t.Fatal("private event did not report its stage timings")
		}
	}
}
