package preferences

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestRejectNilActorAndConversationUUIDs(t *testing.T) {
	input := Input{AccountID: "00000000-0000-0000-0000-000000000000", Settings: Default()}
	if err := Validate(input); !errors.Is(err, ErrInvalid) {
		t.Fatalf("nil actor accepted: %v", err)
	}
	if _, err := New(&fakeStore{}).Read(context.Background(), input.AccountID); !errors.Is(err, ErrInvalid) {
		t.Fatalf("nil read actor accepted: %v", err)
	}
	input.AccountID = "11111111-1111-4111-8111-111111111111"
	input.Settings.Overrides = []Override{{Kind: "CHANNEL", ID: "00000000-0000-0000-0000-000000000000", Preference: Preference{Mode: ModeAll}}}
	if err := Validate(input); !errors.Is(err, ErrInvalid) {
		t.Fatalf("nil conversation accepted: %v", err)
	}
}

func TestZeroOffsetPauseAndCanonicalDuplicate(t *testing.T) {
	pause := time.Date(2026, 10, 25, 12, 0, 0, 0, time.FixedZone("UTC alias", 0))
	input := Input{AccountID: "11111111-1111-4111-8111-111111111111", Settings: Default()}
	input.Settings.DM.PausedUntil = &pause
	if err := Validate(input); err != nil {
		t.Fatal(err)
	}
	one := Override{Kind: "CHANNEL", ID: "abcdefab-abcd-4abc-8abc-abcdefabcdef", Preference: Preference{Mode: ModeNone}}
	two := one
	two.ID = "ABCDEFAB-ABCD-4ABC-8ABC-ABCDEFABCDEF"
	input.Settings.Overrides = []Override{one, two}
	if err := Validate(input); !errors.Is(err, ErrInvalid) {
		t.Fatalf("alias duplicate accepted: %v", err)
	}
}
