package httpmetrics

import (
	"strings"
	"testing"
	"time"
)

func TestRealtimeStageMetricsHaveOnlyFixedStages(t *testing.T) {
	r := New()
	r.ObserveRealtimeEventStages(5*time.Millisecond, 7*time.Millisecond)
	r.ObserveRealtimeEventStages(-time.Second, time.Millisecond)
	text := scrapeMetrics(r)
	for _, want := range []string{`voice_platform_realtime_event_stage_seconds_count{stage="before_handler"} 1`, `voice_platform_realtime_event_stage_seconds_count{stage="handler"} 1`} {
		if !strings.Contains(text, want) {
			t.Fatalf("missing %q", want)
		}
	}
	for _, secret := range []string{"account_id", "message_id", "event_id"} {
		if strings.Contains(text, secret) {
			t.Fatalf("unexpected %s", secret)
		}
	}
}
