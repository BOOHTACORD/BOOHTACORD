package admitlogin

import (
	"context"
	"github.com/prometheus/client_golang/prometheus"
	"testing"
	"time"
)

func TestMetricsHaveOnlyFiniteDecisionAndOutcomeLabels(t *testing.T) {
	budget := testBudget(t, 1, 1, time.Now)
	permit, _, _ := budget.Reserve(context.Background(), "synthetic-private-login")
	permit.Complete(Invalid)
	budget.Reserve(context.Background(), "synthetic-private-login")
	budget.Reserve(context.Background(), "other-synthetic-login")
	registry := prometheus.NewPedanticRegistry()
	registry.MustRegister(NewCollector(budget))
	families, err := registry.Gather()
	if err != nil {
		t.Fatal(err)
	}
	if len(families) != 6 {
		t.Fatalf("metric families=%d want 6", len(families))
	}
	for _, family := range families {
		for _, metric := range family.Metric {
			for _, label := range metric.Label {
				if label.GetName() != "decision" && label.GetName() != "outcome" {
					t.Fatal("identifier label in auth metrics")
				}
				switch label.GetValue() {
				case "admitted", "limited", "saturated", "invalid":
				default:
					t.Fatal("unexpected metric label value")
				}
			}
		}
	}
}
