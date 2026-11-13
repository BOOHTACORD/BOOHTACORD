package connect_realtime

import (
	"context"
	"testing"
	"time"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/record_results"
)

func TestEveryConcurrentWaiterObservesTheSameDeliveredMessage(t *testing.T) {
	socket := New(record_results.New())
	connection := &websocket.Conn{}
	socket.conn = connection
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	started := make(chan struct{}, 2)
	results := make(chan error, 2)
	for range 2 {
		go func() {
			started <- struct{}{}
			_, err := socket.Wait(ctx, "delivered", time.Now())
			results <- err
		}()
	}
	<-started
	<-started
	time.Sleep(50 * time.Millisecond)
	event := Event{ID: "event", Kind: "message.created"}
	event.Payload.MessageID = "delivered"
	if !socket.apply(connection, event, false) {
		t.Fatal("event rejected")
	}
	for range 2 {
		if err := <-results; err != nil {
			t.Fatalf("delivered event was missed: %v", err)
		}
	}
}

func TestSocketFailureWakesAllPendingWaiters(t *testing.T) {
	socket := New(record_results.New())
	connection := &websocket.Conn{}
	socket.conn = connection
	results := make(chan error, 2)
	for range 2 {
		go func() {
			_, err := socket.Wait(context.Background(), "not-delivered", time.Now())
			results <- err
		}()
	}
	time.Sleep(50 * time.Millisecond)
	socket.markFailed(connection)
	for range 2 {
		select {
		case err := <-results:
			if err == nil {
				t.Fatal("failure was treated as delivery")
			}
		case <-time.After(time.Second):
			t.Fatal("waiter did not observe socket failure")
		}
	}
}

func TestWaitFromClosedGenerationCannotConsumeReplacementEvent(t *testing.T) {
	socket := New(record_results.New())
	result := make(chan error, 1)
	go func() {
		_, err := socket.Wait(context.Background(), "replacement", time.Now())
		result <- err
	}()
	time.Sleep(50 * time.Millisecond)
	socket.Close()
	socket.mu.Lock()
	socket.failure = false
	socket.seen["replacement"] = time.Now()
	socket.signalLocked()
	socket.mu.Unlock()
	select {
	case err := <-result:
		if err == nil {
			t.Fatal("old waiter accepted a replacement event")
		}
	case <-time.After(time.Second):
		t.Fatal("old waiter did not finish")
	}
}
