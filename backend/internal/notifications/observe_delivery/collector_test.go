package observedelivery_test

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"strings"
	"testing"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
)

func TestObservationNoDataAndBoundedLabels(t *testing.T) {
	empty := prometheus.NewRegistry()
	empty.MustRegister(observe.NewCollector(nil))
	if err := testutil.GatherAndCompare(empty, strings.NewReader("# HELP boohtacord_notification_observer_up Notification database observation available\n# TYPE boohtacord_notification_observer_up gauge\nboohtacord_notification_observer_up 0\n")); err != nil {
		t.Fatal(err)
	}
	pool := fixture.New(t)
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `INSERT INTO notification_counters(metric,reason,transport,value)VALUES('retry','private-endpoint-secret','web_push',4)`); err != nil {
		t.Fatal(err)
	}
	registry := prometheus.NewRegistry()
	registry.MustRegister(observe.NewCollector(pool))
	families, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	for _, family := range families {
		for _, metric := range family.Metric {
			for _, label := range metric.Label {
				if strings.Contains(label.GetValue(), "private") {
					t.Fatal("unbounded stored label escaped")
				}
			}
		}
	}
}
