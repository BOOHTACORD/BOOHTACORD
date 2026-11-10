package runrostermatrix

import (
	"context"
	"errors"
	"testing"
	"time"
	chat "voice-platform/backend/internal/load/matrix_chat"
)

func TestFirstMessageCapturesBeforeAndAfterProbe(t *testing.T) {
	c, _ := chat.New(1)
	calls := 0
	probe := func(context.Context) (map[string]float64, error) {
		calls++
		return map[string]float64{"count": float64(calls)}, nil
	}
	send := func(context.Context) (string, error) {
		if calls != 1 {
			t.Errorf("probe before send: %d", calls)
		}
		c.Observe(0, "11111111-1111-4111-8111-111111111111", time.Now())
		return "11111111-1111-4111-8111-111111111111", nil
	}
	report, err := measureMessagesWithProbe(context.Background(), c, 1, send, probe)
	if err != nil || calls != 2 || report.ServerBefore["count"] != 1 || report.ServerAfter["count"] != 2 {
		t.Fatalf("probe: %+v %v", report, err)
	}
}

func TestProbeFailureFailsMeasurement(t *testing.T) {
	c, _ := chat.New(1)
	_, err := measureMessagesWithProbe(context.Background(), c, 1, func(context.Context) (string, error) { t.Fatal("send after probe failure"); return "", nil }, func(context.Context) (map[string]float64, error) { return nil, errors.New("unavailable") })
	if err == nil {
		t.Fatal("missing probe accepted")
	}
}
