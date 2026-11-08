package normalizeroster

import (
	"errors"
	"strings"
	"testing"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

const first = "11111111-1111-4111-8111-111111111111"
const second = "22222222-2222-4222-8222-222222222222"

func TestCanonicalOrderEmptyArraysAndInputImmutability(t *testing.T) {
	input := roster.Result{Channels: []roster.ChannelRoster{
		{ChannelID: second, Participants: nil},
		{ChannelID: first, Participants: []roster.Participant{{AccountID: second, DisplayName: "B"}, {AccountID: first, DisplayName: "A"}}},
	}}
	normal, encoded, err := Canonicalize(input, 4096)
	if err != nil {
		t.Fatal(err)
	}
	if normal.Channels[0].ChannelID != first || normal.Channels[0].Participants[0].AccountID != first || normal.Channels[1].Participants == nil {
		t.Fatalf("normalized: %+v", normal)
	}
	if input.Channels[0].ChannelID != second || input.Channels[1].Participants[0].AccountID != second || input.Channels[0].Participants != nil {
		t.Fatal("input mutated")
	}
	_, repeated, err := Canonicalize(normal, 4096)
	if err != nil || string(encoded) != string(repeated) {
		t.Fatal("canonical encoding changed")
	}
	empty, data, err := Canonicalize(roster.Result{}, 4096)
	if err != nil || empty.Channels == nil || string(data) != `{"channels":[]}` {
		t.Fatalf("empty: %s %v", data, err)
	}
}

func TestRejectsMalformedDuplicateAndOversizedResults(t *testing.T) {
	for _, input := range []roster.Result{
		{Channels: []roster.ChannelRoster{{ChannelID: "bad"}}},
		{Channels: []roster.ChannelRoster{{ChannelID: first}, {ChannelID: first}}},
		{Channels: []roster.ChannelRoster{{ChannelID: first, Participants: []roster.Participant{{AccountID: second, DisplayName: "A"}, {AccountID: second, DisplayName: "B"}}}}},
		{Channels: []roster.ChannelRoster{{ChannelID: first, Participants: []roster.Participant{{AccountID: "bad", DisplayName: "A"}}}}},
		{Channels: []roster.ChannelRoster{{ChannelID: first, Participants: []roster.Participant{{AccountID: second, DisplayName: strings.Repeat("Я", 65)}}}}},
	} {
		if _, _, err := Canonicalize(input, 4096); !errors.Is(err, ErrInvalidSnapshot) {
			t.Fatalf("invalid snapshot accepted: %+v, %v", input, err)
		}
	}
	valid := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: first}}}
	if _, _, err := Canonicalize(valid, 4); !errors.Is(err, ErrSnapshotTooLarge) {
		t.Fatalf("oversize: %v", err)
	}
	if _, _, err := Canonicalize(valid, 0); !errors.Is(err, ErrInvalidSnapshot) {
		t.Fatalf("invalid bound: %v", err)
	}
}
