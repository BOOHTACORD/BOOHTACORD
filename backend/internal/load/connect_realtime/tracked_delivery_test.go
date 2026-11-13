package connect_realtime

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/record_results"
)

func TestTrackedDeliverySurvivesBoundedUnrelatedEventFlood(t *testing.T) {
	socket := New(record_results.New())
	connection := &websocket.Conn{}
	socket.conn = connection
	release, err := socket.Track("awaited")
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	started := time.Now()
	event := Event{Kind: "message.created"}
	event.Payload.MessageID = "awaited"
	socket.apply(connection, event, false)
	for i := 0; i < 2048; i++ {
		event.Payload.MessageID = fmt.Sprintf("other-%d", i)
		socket.apply(connection, event, false)
	}
	if len(socket.seen) > 512 {
		t.Fatal("delivery cache exceeded its bound")
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, err := socket.Wait(ctx, "awaited", started); err != nil {
		t.Fatal("delivered and tracked message was lost under unrelated traffic", err)
	}
}

func TestTrackedDeliveryLimitAndReleaseAreBounded(t *testing.T) {
	socket := New(record_results.New())
	socket.conn = &websocket.Conn{}
	var first func()
	for i := 0; i < 512; i++ {
		release, err := socket.Track(fmt.Sprintf("expected-%d", i))
		if err != nil {
			t.Fatal(err)
		}
		if i == 0 {
			first = release
		}
	}
	if _, err := socket.Track("overflow"); err == nil {
		t.Fatal("unbounded expected-message tracking")
	}
	first()
	first()
	if release, err := socket.Track("after-release"); err != nil {
		t.Fatal(err)
	} else {
		release()
	}
}

func TestOldGenerationReleaseCannotUnpinNewGeneration(t *testing.T) {
	socket := New(record_results.New())
	connection := &websocket.Conn{}
	socket.conn = connection
	oldRelease, err := socket.Track("awaited")
	if err != nil {
		t.Fatal(err)
	}
	socket.mu.Lock()
	socket.conn = nil // Do not close the uninitialized test connection.
	socket.mu.Unlock()
	socket.Close()
	socket.mu.Lock()
	socket.conn, socket.failure = connection, false
	socket.mu.Unlock()
	newRelease, err := socket.Track("awaited")
	if err != nil {
		t.Fatal(err)
	}
	defer newRelease()
	oldRelease()
	socket.mu.Lock()
	defer socket.mu.Unlock()
	if socket.tracked["awaited"] != 1 {
		t.Fatal("old release unpinned the replacement socket")
	}
}
