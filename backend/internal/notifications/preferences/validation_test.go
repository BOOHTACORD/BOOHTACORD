package preferences

import (
	"errors"
	"testing"
	"time"
)

func TestValidateAcceptsExplicitOverrideSetWithinLimit(t *testing.T) {
	pause := time.Date(2026, 10, 25, 8, 30, 0, 0, time.UTC)
	input := Input{
		AccountID:        "11111111-1111-1111-1111-111111111111",
		ExpectedRevision: 0,
		Settings: Settings{
			Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions},
			Overrides: []Override{
				{Kind: "CHANNEL", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeNone, PausedUntil: &pause}},
				{Kind: "DIRECT_MESSAGE", ID: "33333333-3333-3333-3333-333333333333", Preference: Preference{Mode: ModeMentions}},
			},
		},
	}
	if err := Validate(input); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
}

func TestValidateRejectsDuplicateOverrideAndAllowsSameUUIDAcrossKinds(t *testing.T) {
	base := Input{AccountID: "11111111-1111-1111-1111-111111111111", Settings: Settings{Version: 1, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}}}
	base.Settings.Overrides = []Override{{Kind: "CHANNEL", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeNone}}, {Kind: "CHANNEL", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeAll}}}
	if err := Validate(base); !errors.Is(err, ErrInvalid) {
		t.Fatalf("Validate(same kind+id duplicate) = %v, want ErrInvalid", err)
	}
	base.Settings.Overrides = []Override{{Kind: "CHANNEL", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeNone}}, {Kind: "DIRECT_MESSAGE", ID: "22222222-2222-2222-2222-222222222222", Preference: Preference{Mode: ModeAll}}}
	if err := Validate(base); err != nil {
		t.Fatalf("Validate(same UUID across kinds) = %v, want nil", err)
	}
}
