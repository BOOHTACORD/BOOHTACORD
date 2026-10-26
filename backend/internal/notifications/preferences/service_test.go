package preferences

import (
	"context"
	"encoding/json"
	"errors"
	"reflect"
	"testing"
	"time"
)

func equal(a, b any) bool {
	aJSON, _ := json.Marshal(a)
	bJSON, _ := json.Marshal(b)
	return reflect.DeepEqual(aJSON, bJSON)
}

func TestDefaultIsVersionOneRevisionZeroAndDisabled(t *testing.T) {
	defaults := Default()
	if defaults.Version != 1 || defaults.Revision != 0 || defaults.Enabled || defaults.Imported {
		t.Fatalf("Default() = %#v", defaults)
	}
	if defaults.DM.Mode != ModeAll || defaults.Text.Mode != ModeMentions || defaults.DM.PausedUntil != nil || len(defaults.Overrides) != 0 {
		t.Fatalf("Default() = %#v", defaults)
	}
}

func TestSaveValidatesActorVersionAndModesBeforeStore(t *testing.T) {
	store := &fakeStore{}
	cases := map[string]Input{
		"actor":     {AccountID: "not-a-uuid"},
		"version":   {AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 2, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}}},
		"dm mode":   {AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: "loud"}, Text: Preference{Mode: ModeMentions}}},
		"text mode": {AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ""}}},
		"revision":  {AccountID: "11111111-1111-1111-1111-111111111111", ExpectedRevision: -1, Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}}},
		"offset":    {AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll, PausedUntil: pauseAt(time.FixedZone("MSK", 3*60*60))}, Text: Preference{Mode: ModeMentions}}},
		"override":  {AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}, Overrides: []Override{{Kind: "GUILD", ID: "22222222-2222-2222-2222-222222222222"}}}},
	}
	for name, input := range cases {
		if _, err := New(store).Save(context.Background(), input); !errors.Is(err, ErrInvalid) || store.called {
			t.Fatalf("Save(%s) error = %v, persisted = %v", name, err, store.called)
		}
	}
}

func TestSaveAcceptsUTCFutureAndPastPausesAndPassesInputThrough(t *testing.T) {
	store := &fakeStore{settings: Settings{Version: 1, Revision: 7}}
	past := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	future := time.Date(2026, 12, 31, 23, 59, 59, 0, time.UTC)
	input := Input{AccountID: "11111111-1111-1111-1111-111111111111", ExpectedRevision: 6, Settings: Settings{Version: 1, Enabled: true, DM: Preference{Mode: ModeNone, PausedUntil: &past}, Text: Preference{Mode: ModeAll, PausedUntil: &future}}}
	settings, err := New(store).Save(context.Background(), input)
	if err != nil || !store.called || !equal(store.input, input) {
		t.Fatalf("Save() = %#v, %v; input = %#v", settings, err, store.input)
	}
	if !equal(settings, store.settings) {
		t.Fatalf("Save() = %#v, want store result %#v", settings, store.settings)
	}
}

func TestSaveRejectsDuplicateAndOversizedOverrides(t *testing.T) {
	store := &fakeStore{}
	duplicate := Override{Kind: "CHANNEL", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeNone}}
	input := Input{AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}, Overrides: []Override{duplicate, duplicate}}}
	if _, err := New(store).Save(context.Background(), input); !errors.Is(err, ErrInvalid) || store.called {
		t.Fatalf("Save(duplicate) error = %v", err)
	}
	overrides := make([]Override, 0, maxOverrides+1)
	for index := 0; index <= maxOverrides; index++ {
		overrides = append(overrides, Override{Kind: "DIRECT_MESSAGE", ID: "33333333-3333-3333-3333-333333333333", Preference: Preference{Mode: ModeNone}})
	}
	input.Settings.Overrides = overrides
	if _, err := New(store).Save(context.Background(), input); !errors.Is(err, ErrInvalid) || store.called {
		t.Fatalf("Save(101 overrides) error = %v", err)
	}
}

func TestReadRequiresUUIDAndPropagatesStoreError(t *testing.T) {
	store := &fakeStore{err: errors.New("store down")}
	if _, err := New(store).Read(context.Background(), "not-a-uuid"); !errors.Is(err, ErrInvalid) || store.called {
		t.Fatalf("Read(bad actor) error = %v", err)
	}
	store.err = nil
	settings, err := New(store).Read(context.Background(), "11111111-1111-1111-1111-111111111111")
	if err != nil || settings.Revision != 7 {
		t.Fatalf("Read() = %#v, %v", settings, err)
	}
	store.err = errors.New("store down")
	if _, err := New(store).Read(context.Background(), "11111111-1111-1111-1111-111111111111"); err == nil {
		t.Fatal("Read() expected store error")
	}
	if _, err := New(store).Save(context.Background(), Input{AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}}}); err == nil {
		t.Fatal("Save() expected store error")
	}
}

func pauseAt(zone *time.Location) *time.Time {
	value := time.Date(2026, 11, 1, 12, 0, 0, 0, zone)
	return &value
}
