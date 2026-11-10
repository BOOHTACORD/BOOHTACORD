package rosterdependencymetrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"testing"
	"time"
)

func TestFailedRoomServiceCallDoesNotClaimSuccess(t *testing.T) {
	m := New(prometheus.NewRegistry())
	m.Call("ListRooms", "http_error", time.Millisecond)
	if m.fresh.latest["ListRooms"][1] != 0 {
		t.Fatal("failed call claimed last success")
	}
}
