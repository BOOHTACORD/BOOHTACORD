package eventhub

import (
	"errors"
	"testing"
	"time"
)

func TestInactiveGuardSerializesActivityAndRejectsFreshInput(t *testing.T) {
	hub := New(8)
	socket := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-2*time.Minute))
	defer socket.Close()
	entered, release := make(chan struct{}), make(chan struct{})
	finished := make(chan error, 1)
	go func() {
		_, err := hub.IfInactive("account", time.Now().Add(-time.Minute), func() error {
			close(entered)
			<-release
			return nil
		})
		finished <- err
	}()
	<-entered
	activityDone := make(chan struct{})
	go func() { hub.ReportActivity(socket, time.Now()); close(activityDone) }()
	select {
	case <-activityDone:
		t.Fatal("activity changed during the guarded transition")
	case <-time.After(30 * time.Millisecond):
	}
	close(release)
	if err := <-finished; err != nil {
		t.Fatal(err)
	}
	<-activityDone
	called := false
	moved, err := hub.IfInactive("account", time.Now().Add(-time.Minute), func() error {
		called = true
		return nil
	})
	if err != nil || moved || called {
		t.Fatalf("fresh input was ignored: %v %v %v", moved, called, err)
	}
}

func TestInactiveGuardPropagatesFailureAndRejectsUnknown(t *testing.T) {
	hub := New(8)
	if moved, err := hub.IfInactive("missing", time.Now(), func() error { t.Fatal("unknown account"); return nil }); moved || err != nil {
		t.Fatalf("unknown account: %v %v", moved, err)
	}
	socket := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-2*time.Minute))
	defer socket.Close()
	want := errors.New("transaction failed")
	moved, err := hub.IfInactive("account", time.Now(), func() error { return want })
	if moved || !errors.Is(err, want) {
		t.Fatalf("failed transaction: %v %v", moved, err)
	}
}
