package rostermatrix

import (
	"strings"
	"testing"
	"time"
)

func TestLegacyFixtureDistinguishesEmptyRosterAndUnknown(t *testing.T) {
	var seen []string
	observe := func(kind string, _ time.Duration) { seen = append(seen, kind) }
	err := ReadLegacy(strings.NewReader("data: {\"channels\":[]}\n\n"), "roster", nil, time.Now(), observe)
	if err == nil || len(seen) != 1 || seen[0] != "roster" {
		t.Fatal("legacy stream must report valid snapshot and unexpected EOF")
	}
	seen = nil
	_ = ReadLegacy(strings.NewReader("event: roster-unavailable\ndata: {}\n\n"), "roster", nil, time.Now(), observe)
	if len(seen) != 0 {
		t.Fatal("unavailable treated as an empty roster")
	}
	_ = ReadLegacy(strings.NewReader("data: {}\n\n"), "maintenance", nil, time.Now(), observe)
	if len(seen) != 0 {
		t.Fatal("unknown maintenance treated as inactive")
	}
}

func TestLegacyFixtureAcceptsBooleanMaintenance(t *testing.T) {
	var seen []string
	_ = ReadLegacy(strings.NewReader(": heartbeat\n\ndata: {\"active\":false}\n\n"), "maintenance", nil, time.Now(), func(kind string, _ time.Duration) { seen = append(seen, kind) })
	if len(seen) != 1 || seen[0] != "maintenance" {
		t.Fatal("maintenance event missing")
	}
}

func TestLegacyFixtureRecognizesMaintenanceActivation(t *testing.T) {
	var seen []string
	_ = ReadLegacy(strings.NewReader("data: {\"active\":true}\n\n"), "maintenance", nil, time.Now(), func(kind string, _ time.Duration) { seen = append(seen, kind) })
	if len(seen) != 1 || seen[0] != "maintenance_change" {
		t.Fatal("maintenance activation was not distinguished")
	}
}
