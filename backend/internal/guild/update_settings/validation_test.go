package guildsettings

import (
	"strings"
	"testing"
)

func TestNameValidationPreservesInteriorAndCase(t *testing.T) {
	input := Input{SetName: true, Name: "  Моя  Гильдия  ", ExpectedRevision: 1}
	got, err := Validate(input)
	if err != nil || got.Name != "Моя  Гильдия" {
		t.Fatal("name normalization changed interior")
	}
	for _, name := range []string{"", "  ", "a\nb", "a\tb", "a\x00b", strings.Repeat("я", 81)} {
		input.Name = name
		if _, err := Validate(input); err == nil {
			t.Fatal("invalid name accepted")
		}
	}
	input.Name = strings.Repeat("я", 80)
	if _, err := Validate(input); err != nil {
		t.Fatal("80 Unicode codepoints rejected")
	}
}
func TestWelcomePatchPresenceAndRevision(t *testing.T) {
	for _, input := range []Input{{ExpectedRevision: 1}, {SetWelcome: true, ExpectedRevision: 0}, {SetWelcome: true, WelcomeChannelID: "bad", ExpectedRevision: 1}} {
		if _, err := Validate(input); err == nil {
			t.Fatal("invalid settings accepted")
		}
	}
	if _, err := Validate(Input{SetWelcome: true, ExpectedRevision: 1}); err != nil {
		t.Fatal("disable rejected")
	}
}

func TestAFKSettingsRequireAnActiveChannelAndBoundedTimeout(t *testing.T) {
	channel := "11111111-1111-4111-8111-111111111111"
	for _, input := range []Input{
		{SetAFK: true, ExpectedRevision: 1, AFKTimeoutSeconds: 300},
		{SetAFK: true, ExpectedRevision: 1, AFKChannelID: "invalid", AFKTimeoutSeconds: 300},
		{SetAFK: true, ExpectedRevision: 1, AFKChannelID: channel, AFKTimeoutSeconds: 59},
		{SetAFK: true, ExpectedRevision: 1, AFKChannelID: channel, AFKTimeoutSeconds: 86401},
	} {
		if _, err := Validate(input); err == nil {
			t.Fatalf("invalid AFK settings accepted: %#v", input)
		}
	}
	if _, err := Validate(Input{SetAFK: true, ExpectedRevision: 1, AFKTimeoutSeconds: 0}); err != nil {
		t.Fatalf("disable AFK routing rejected: %v", err)
	}
	if _, err := Validate(Input{SetAFK: true, ExpectedRevision: 1, AFKChannelID: channel, AFKTimeoutSeconds: 60}); err != nil {
		t.Fatalf("valid AFK settings rejected: %v", err)
	}
}
