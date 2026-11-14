package snapshotlivekitpresence

import (
	"context"
	"strings"

	"github.com/google/uuid"
	"github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/livekit"
)

type ConnectedLease struct {
	LeaseID         string
	ScreenSharing   bool
	MicrophoneMuted bool
	Deafened        bool
}

const VoiceDeafenedAttribute = "boohtacord.voice.deafened.v1"

// SnapshotRooms returns ICE-connected lease identities in current VOICE rooms.
// Caller must intersect them with current database leases before disclosure.
func (client Client) SnapshotRooms(ctx context.Context, channelIDs []string) (map[string][]ConnectedLease, error) {
	result := make(map[string][]ConnectedLease)
	if len(channelIDs) == 0 {
		return result, nil
	}
	names := make([]string, 0, len(channelIDs))
	requested := make(map[string]string, len(channelIDs))
	for _, id := range channelIDs {
		if uuid.Validate(id) != nil {
			return nil, unavailable("validation")
		}
		name := "voice:" + id
		if _, exists := requested[name]; exists {
			continue
		}
		requested[name] = id
		names = append(names, name)
	}
	listToken, err := client.token(auth.VideoGrant{RoomList: true})
	if err != nil {
		return nil, unavailable("token")
	}
	rooms, err := client.service(listToken).ListRooms(ctx, &livekit.ListRoomsRequest{Names: names})
	if err != nil || rooms == nil {
		return nil, unavailableCause("room_list", err)
	}
	seen := make(map[string]bool, len(rooms.GetRooms()))
	for _, room := range rooms.GetRooms() {
		if room == nil {
			return nil, unavailable("validation")
		}
		name := room.GetName()
		id, allowed := requested[name]
		if !allowed || seen[name] {
			return nil, unavailable("validation")
		}
		seen[name] = true
		participantToken, err := client.token(auth.VideoGrant{RoomAdmin: true, Room: name})
		if err != nil {
			return nil, unavailable("token")
		}
		participants, err := client.service(participantToken).ListParticipants(ctx, &livekit.ListParticipantsRequest{Room: name})
		if err != nil || participants == nil {
			return nil, unavailableCause("participants", err)
		}
		for _, participant := range participants.GetParticipants() {
			if participant == nil || participant.GetState() != livekit.ParticipantInfo_ACTIVE {
				continue
			}
			identity := participant.GetIdentity()
			if !strings.HasPrefix(identity, "voice-lease:") {
				continue
			}
			leaseID := strings.TrimPrefix(identity, "voice-lease:")
			if uuid.Validate(leaseID) != nil {
				continue
			}
			connected := ConnectedLease{LeaseID: leaseID, MicrophoneMuted: true}
			connected.Deafened = participant.GetAttributes()[VoiceDeafenedAttribute] == "true"
			for _, track := range participant.GetTracks() {
				if track != nil && track.GetType() == livekit.TrackType_AUDIO && track.GetSource() == livekit.TrackSource_MICROPHONE && !track.GetMuted() {
					connected.MicrophoneMuted = false
				}
				if track != nil && !track.GetMuted() && track.GetType() == livekit.TrackType_VIDEO && track.GetSource() == livekit.TrackSource_SCREEN_SHARE {
					connected.ScreenSharing = true
				}
			}
			result[id] = append(result[id], connected)
		}
	}
	return result, nil
}
