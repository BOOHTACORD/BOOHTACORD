package normalizeroster

import (
	"encoding/json"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

// Encode the complete public v2 state so every visible change advances the
// coordinator revision, while internal lease proofs remain private.
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
