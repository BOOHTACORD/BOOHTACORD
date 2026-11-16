package normalizeroster

import (
	"bytes"
	"errors"
	"strings"
	"testing"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestDeafenedChangesCanonicalEncodingAndRespectsBound(t *testing.T) {
	input := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: first, Participants: []roster.Participant{{AccountID: second, DisplayName: "Test"}}}}}
	_, before, err := Canonicalize(input, 4096)
	if err != nil {
		t.Fatal(err)
	}
	input.Channels[0].Participants[0].Deafened = true
	_, after, err := Canonicalize(input, 4096)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(before, after) {
		t.Fatal("deafen-only change is invisible to canonical comparison")
	}
	if !strings.Contains(string(after), `"deafened":true`) {
		t.Fatal("v2 canonical state omitted the deafen value")
	}
	if _, _, err := Canonicalize(input, len(after)-1); !errors.Is(err, ErrSnapshotTooLarge) {
		t.Fatal("v2 canonical state exceeded its transport bound")
	}
}
