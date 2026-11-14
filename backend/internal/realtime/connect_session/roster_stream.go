package connectsession

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

type RosterDelivery = prepared.Delivery

type RosterStream interface {
	Events() <-chan RosterDelivery
	Current(coordinator.State) bool
	RequestRefresh() bool
	Check(context.Context, coordinator.State) error
	WithRoster(context.Context, coordinator.State, func(context.Context) error) error
	Close()
}
type rosterVersionStream struct {
	RosterStream
	version int
}

func (stream rosterVersionStream) rosterVersion() int { return stream.version }
func (stream rosterVersionStream) ObserveRosterUnavailable(duration time.Duration, success bool) {
	if observer, ok := stream.RosterStream.(interface {
		ObserveRosterUnavailable(time.Duration, bool)
	}); ok {
		observer.ObserveRosterUnavailable(duration, success)
	}
}

type RosterFactory func(context.Context, auth.Principal, *http.Cookie) (RosterStream, error)

func closeRoster(stream RosterStream) {
	if stream != nil {
		stream.Close()
	}
}

func subscribeRoster(request *http.Request, principal auth.Principal, cookie *http.Cookie, factory RosterFactory) (RosterStream, error) {
	capabilities := requestedCapabilities(request)
	version := 0
	for _, capability := range capabilities {
		if capability == "voice_roster_v2" {
			version = 2
		}
	}
	if version == 0 {
		for _, capability := range capabilities {
			if capability == "voice_roster_v1" {
				version = 1
			}
		}
	}
	if version != 0 {
		if factory == nil || cookie == nil {
			return nil, errors.New("roster unavailable")
		}
		stream, err := factory(request.Context(), principal, cookie)
		if err != nil || stream == nil {
			return nil, errors.New("roster unavailable")
		}
		return rosterVersionStream{RosterStream: stream, version: version}, nil
	}
	return nil, nil
}

func writeRoster(connection *websocket.Conn, sub RosterStream, delivery RosterDelivery, maxBytes int, newID Identifier, now Clock) bool {
	if delivery.SessionInvalid {
		_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
		return false
	}
	if !delivery.Unavailable && !sub.Current(delivery.State) {
		return sub.RequestRefresh()
	}
	if maxBytes <= 0 {
		maxBytes = 1 << 20
	}
	state := delivery.State
	payload := map[string]any{"version": 1, "generation": state.Generation, "revision": state.Revision, "observed_at": state.ObservedAt.UTC(), "channels": state.Roster.Channels}
	kind := "voice.roster.snapshot"
	version := 1
	if versioned, ok := sub.(interface{ rosterVersion() int }); ok && versioned.rosterVersion() == 2 {
		version = 2
		kind = "voice.roster.snapshot.v2"
		payload = map[string]any{"version": 2, "generation": state.Generation, "revision": state.Revision, "observed_at": state.ObservedAt.UTC(), "channels": rosterChannelsV2(state.Roster)}
	}
	if delivery.Unavailable || state.Revision == 0 || state.Revision > 9007199254740991 || state.ObservedAt.IsZero() || state.Roster.Channels == nil {
		kind, payload = unavailableRoster(version)
	} else if _, err := uuid.Parse(state.Generation); err != nil {
		kind, payload = unavailableRoster(version)
	}
	frame, err := json.Marshal(Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload})
	if err != nil || len(frame) > maxBytes {
		kind, payload = unavailableRoster(version)
		frame, err = json.Marshal(Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload})
	}
	if err != nil || len(frame) > maxBytes {
		return false
	}
	if isRosterSnapshot(kind) && !sub.Current(state) {
		return sub.RequestRefresh()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if !isRosterSnapshot(kind) {
		started := time.Now()
		err := connection.Write(ctx, websocket.MessageText, frame)
		if observer, ok := sub.(interface{ ObserveRosterUnavailable(time.Duration, bool) }); ok {
			observer.ObserveRosterUnavailable(time.Since(started), err == nil)
		}
		return err == nil
	}
	err = sub.WithRoster(ctx, state, func(writeCtx context.Context) error {
		if !sub.Current(state) {
			return guard.ErrStale
		}
		return connection.Write(writeCtx, websocket.MessageText, frame)
	})
	if errors.Is(err, guard.ErrSession) {
		_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
		return false
	}
	if errors.Is(err, guard.ErrStale) {
		return sub.RequestRefresh()
	}
	if errors.Is(err, guard.ErrUnavailable) {
		return writeRoster(connection, sub, RosterDelivery{Unavailable: true}, maxBytes, newID, now)
	}
	return err == nil
}

func unavailableRoster(version int) (string, map[string]any) {
	if version == 2 {
		return "voice.roster.unavailable.v2", map[string]any{"version": 2, "code": "temporarily_unavailable"}
	}
	return "voice.roster.unavailable", map[string]any{"version": 1, "code": "temporarily_unavailable"}
}
func isRosterSnapshot(kind string) bool {
	return kind == "voice.roster.snapshot" || kind == "voice.roster.snapshot.v2"
}
func rosterChannelsV2(source roster.Result) []roster.ChannelRosterV2 {
	result := make([]roster.ChannelRosterV2, 0, len(source.Channels))
	for _, channel := range source.Channels {
		item := roster.ChannelRosterV2{ChannelID: channel.ChannelID, Participants: make([]roster.ParticipantV2, 0, len(channel.Participants))}
		for _, member := range channel.Participants {
			item.Participants = append(item.Participants, roster.ParticipantV2{AccountID: member.AccountID, DisplayName: member.DisplayName, ScreenSharing: member.ScreenSharing, MicrophoneMuted: member.MicrophoneMuted, Deafened: member.Deafened})
		}
		result = append(result, item)
	}
	return result
}
