package runrostermatrix

import (
	"testing"
	"time"
)

func TestInitialMetricsAreDistinctBoundedAndDeduplicated(t *testing.T) {
	m := NewMeasurements(2)
	for i := 0; i < 2; i++ {
		m.Observe(i, "ready", time.Duration(i+1)*time.Millisecond)
		m.Observe(i, "roster", time.Duration(i+3)*time.Millisecond)
		m.Observe(i, "maintenance", time.Duration(i+5)*time.Millisecond)
	}
	m.Observe(0, "roster", 999*time.Millisecond)
	m.Observe(-1, "roster", 999*time.Millisecond)
	m.Observe(2, "roster", 999*time.Millisecond)
	m.Observe(0, "unknown", 999*time.Millisecond)
	if !m.Complete() {
		t.Fatal("complete fixture reported incomplete")
	}
	rows := m.Snapshot()
	if rows["ready"].Count != 2 || rows["roster"].P95MS != 4 || rows["maintenance"].P50MS != 5 {
		t.Fatalf("unexpected aggregate: %#v", rows)
	}
}

func TestMissingDomainCannotPass(t *testing.T) {
	m := NewMeasurements(1)
	m.Observe(0, "ready", time.Millisecond)
	m.Observe(0, "maintenance", time.Millisecond)
	if m.Complete() {
		t.Fatal("ready without roster passed")
	}
}

func TestPublicMeasurementsDoNotFabricateRosterOrBaselineReady(t *testing.T) {
	baseline := NewPublicMeasurements(1, false)
	baseline.Observe(0, "maintenance", time.Millisecond)
	if !baseline.Complete() || baseline.Snapshot()["ready"].Count != 0 || baseline.Snapshot()["roster"].Count != 0 {
		t.Fatal("baseline public stream requirements were misrepresented")
	}
	candidate := NewPublicMeasurements(1, true)
	candidate.Observe(0, "maintenance", time.Millisecond)
	if candidate.Complete() {
		t.Fatal("public websocket without ready passed")
	}
	candidate.Observe(0, "ready", time.Millisecond)
	if !candidate.Complete() {
		t.Fatal("complete public websocket failed")
	}
}

func TestMaintenanceChangeRequiresAnArmedObservationForEveryActor(t *testing.T) {
	m := NewMeasurements(2)
	m.Observe(0, "maintenance_change", time.Millisecond)
	if m.ChangeComplete() {
		t.Fatal("unarmed change passed")
	}
	if err := m.StartMaintenanceChange(time.Now().Add(-time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	m.Observe(0, "maintenance_change", time.Millisecond)
	m.Observe(0, "maintenance_change", time.Millisecond)
	if m.ChangeComplete() {
		t.Fatal("duplicate actor masked missing change")
	}
	m.Observe(1, "maintenance_change", time.Millisecond)
	if !m.ChangeComplete() || m.Snapshot()["maintenance_change"].Count != 2 {
		t.Fatal("complete change was not measured")
	}
	if err := m.StartMaintenanceChange(time.Now()); err == nil {
		t.Fatal("change was armed twice")
	}
}
