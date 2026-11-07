package trackloginfailures

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"testing"
	"time"
)

func TestMetricsContainOnlyFiniteDecisionAndOutcomeLabels(t *testing.T) {
	b := testBudget(t, Config{Limit: 1, Window: time.Minute, Capacity: 1})
	p, _, _ := b.Reserve(context.Background(), "private-synthetic-login")
	p.Finish(true)
	b.Reserve(context.Background(), "private-synthetic-login")
	b.Reserve(context.Background(), "different-private-login")
	r := prometheus.NewPedanticRegistry()
	r.MustRegister(NewCollector(b))
	families, err := r.Gather()
	if err != nil {
		t.Fatal(err)
	}
	if len(families) != 2 {
		t.Fatalf("metric families %d", len(families))
	}
	for _, family := range families {
		for _, metric := range family.Metric {
			for _, label := range metric.Label {
				if label.GetName() != "decision" && label.GetName() != "outcome" {
					t.Fatal("identifier label exported")
				}
				switch label.GetValue() {
				case "admitted", "limited", "saturated", "charged":
				default:
					t.Fatal("unexpected label value")
				}
			}
		}
	}
}
