package publicrealtime

import (
	"context"
	"testing"
	"time"
)

type readMetrics struct{ outcomes chan bool }

func (*readMetrics) PublicRealtimeConnectionOpened()  {}
func (*readMetrics) PublicRealtimeConnectionClosed()  {}
func (m *readMetrics) ObserveMaintenanceRead(ok bool) { m.outcomes <- ok }

func TestSharedObserverReportsReadsToRuntimeRecorder(t *testing.T) {
	metrics := &readMetrics{outcomes: make(chan bool, 2)}
	_, observer, stop, err := StartShared(context.Background(), &testReader{}, "https://example.test", nil, metrics)
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	sub := observer.Subscribe()
	defer sub.Close()
	select {
	case ok := <-metrics.outcomes:
		if !ok {
			t.Fatal("successful read reported failure")
		}
	case <-time.After(time.Second):
		t.Fatal("read outcome not reported")
	}
}
