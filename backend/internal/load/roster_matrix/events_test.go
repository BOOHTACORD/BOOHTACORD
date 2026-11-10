package rostermatrix

import "testing"

func TestCandidateEventsKeepReadyDistinctFromRoster(t *testing.T) {
	ready, err := CandidateEvent([]byte(`{"kind":"connection.ready","payload":{}}`), nil)
	if err != nil || ready != "ready" {
		t.Fatal("connection readiness was not recognized")
	}
	room, err := CandidateEvent([]byte(`{"kind":"voice.roster.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"observed_at":"2026-11-09T00:00:00Z","channels":[]}}`), nil)
	if err != nil || room != "roster" {
		t.Fatal("valid empty roster was not recognized")
	}
	if _, err = CandidateEvent([]byte(`{"kind":"voice.roster.snapshot","payload":{}}`), nil); err == nil {
		t.Fatal("missing snapshot channels accepted")
	}
	if _, err = CandidateEvent([]byte(`{"kind":"voice.roster.unavailable","payload":{}}`), nil); err == nil {
		t.Fatal("unavailable snapshot accepted as empty")
	}
}

func TestCandidateMaintenanceRequiresBooleanState(t *testing.T) {
	for _, raw := range []string{`{"kind":"maintenance.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}}`, `{"kind":"maintenance.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":true}}`} {
		kind, err := CandidateEvent([]byte(raw), nil)
		if err != nil || kind != "maintenance" {
			t.Fatal("valid maintenance snapshot rejected")
		}
	}
	if _, err := CandidateEvent([]byte(`{"kind":"maintenance.snapshot","payload":{}}`), nil); err == nil {
		t.Fatal("unknown maintenance accepted as inactive")
	}
	if _, err := CandidateEvent([]byte(`{"kind":"maintenance.snapshot","payload":{"active":false}}`), nil); err == nil {
		t.Fatal("maintenance without generation accepted")
	}
}

func TestCandidateRecognizesMaintenanceChangeSeparately(t *testing.T) {
	data := []byte(`{"kind":"maintenance.changed","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":2,"active":true}}`)
	kind, err := CandidateEvent(data, nil)
	if err != nil || kind != "maintenance_change" {
		t.Fatalf("maintenance change: %q %v", kind, err)
	}
	if _, err := CandidateEvent([]byte(`{"kind":"maintenance.changed","payload":{}}`), nil); err == nil {
		t.Fatal("invalid change was accepted")
	}
}

func TestPresenceEventCanBeCountedWithoutRetainingItsPayload(t *testing.T) {
	kind, err := CandidateEvent([]byte(`{"kind":"presence.changed","payload":{"presence":"online"}}`), nil)
	if err != nil || kind != "presence" {
		t.Fatalf("presence event: %q %v", kind, err)
	}
}
