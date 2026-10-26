package preferencesapi

import (
	"encoding/json"
	"testing"
	p "voice-platform/backend/internal/notifications/preferences"
)

func TestAdminCannotSaveOtherPairAndReadFiltersRevoked(t *testing.T) {
	settings := p.Default()
	settings.Revision = 7
	settings.Overrides = []p.Override{{Kind: "DIRECT_MESSAGE", ID: "22222222-2222-4222-8222-222222222222", Preference: p.Preference{Mode: p.ModeAll}}}
	s := &fakeService{settings: settings}
	h := NewHandler(s, fakeAccess(false), false, nil)
	if w := request(h, "PUT", "/api/v1/notification-preferences", updateBody(settings), true); w.Code != 404 {
		t.Fatal(w.Code, w.Body.String())
	}
	if s.writes != 0 {
		t.Fatal("unauthorized override saved")
	}
	w := request(h, "GET", "/api/v1/notification-preferences", "", true)
	var body struct {
		Settings p.Settings `json:"settings"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &body)
	if w.Code != 200 || body.Settings.Revision != 7 || len(body.Settings.Overrides) != 0 {
		t.Fatal(w.Code, w.Body.String())
	}
}
