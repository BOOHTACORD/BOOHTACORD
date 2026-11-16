// Package normalizeroster creates deterministic, bounded roster encodings.
package normalizeroster

import (
	"encoding/json"
	"errors"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

var ErrInvalidSnapshot = errors.New("invalid voice roster snapshot")
var ErrSnapshotTooLarge = errors.New("voice roster snapshot exceeds delivery bound")

// Canonicalize copies the complete result; it never truncates authorized data.
// maxBytes is a transport bound, not a channel-count product limit.
func Canonicalize(input roster.Result, maxBytes int) (roster.Result, []byte, error) {
	if maxBytes < 1 {
		return roster.Result{}, nil, ErrInvalidSnapshot
	}
	if len(input.Channels) > maxBytes/36 {
		return roster.Result{}, nil, ErrSnapshotTooLarge
	}
	result := roster.Result{Channels: make([]roster.ChannelRoster, 0, len(input.Channels))}
	seen := make(map[string]bool, len(input.Channels))
	for _, channel := range input.Channels {
		id, ok := canonicalID(channel.ChannelID)
		if !ok || seen[id] {
			return roster.Result{}, nil, ErrInvalidSnapshot
		}
		seen[id] = true
		if len(channel.Participants) > maxBytes/36 {
			return roster.Result{}, nil, ErrSnapshotTooLarge
		}
		participants, err := normalizeParticipants(channel.Participants)
		if err != nil {
			return roster.Result{}, nil, err
		}
		result.Channels = append(result.Channels, roster.ChannelRoster{ChannelID: id, Participants: participants})
	}
	sort.Slice(result.Channels, func(i, j int) bool { return result.Channels[i].ChannelID < result.Channels[j].ChannelID })
	encoded, err := encodeRosterV2(result)
	if err != nil {
		return roster.Result{}, nil, ErrInvalidSnapshot
	}
	if len(encoded) > maxBytes {
		return roster.Result{}, nil, ErrSnapshotTooLarge
	}
	return result, encoded, nil
}

func canonicalID(value string) (string, bool) {
	id, err := uuid.Parse(value)
	if err != nil {
		return "", false
	}
	canonical := id.String()
	return canonical, canonical == strings.ToLower(value)
}

func normalizeParticipants(input []roster.Participant) ([]roster.Participant, error) {
	result := make([]roster.Participant, 0, len(input))
	seen := make(map[string]bool, len(input))
	for _, participant := range input {
		id, ok := canonicalID(participant.AccountID)
		nameLength := utf8.RuneCountInString(participant.DisplayName)
		if !ok || seen[id] || !utf8.ValidString(participant.DisplayName) || nameLength < 1 || nameLength > 64 {
			return nil, ErrInvalidSnapshot
		}
		seen[id] = true
		participant.AccountID = id
		result = append(result, participant)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].AccountID < result[j].AccountID })
	return result, nil
}

// Encode public v2 state for change detection without leaking lease proofs.
func encodeRosterV2(input roster.Result) ([]byte, error) {
	out := roster.ResultV2{Channels: make([]roster.ChannelRosterV2, 0, len(input.Channels))}
	for _, channel := range input.Channels {
		item := roster.ChannelRosterV2{ChannelID: channel.ChannelID, Participants: make([]roster.ParticipantV2, 0, len(channel.Participants))}
		for _, p := range channel.Participants {
			item.Participants = append(item.Participants, roster.ParticipantV2{
				AccountID: p.AccountID, DisplayName: p.DisplayName, ScreenSharing: p.ScreenSharing,
				MicrophoneMuted: p.MicrophoneMuted, Deafened: p.Deafened,
			})
		}
		out.Channels = append(out.Channels, item)
	}
	return json.Marshal(out)
}
