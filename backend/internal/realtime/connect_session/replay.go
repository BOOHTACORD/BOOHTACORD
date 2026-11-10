package connectsession

import (
	"context"
	"errors"
	"net/http"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	replaypostgres "voice-platform/backend/internal/realtime/replay_event/postgres"
)

func loadReplay(ctx context.Context, hub *eventhub.Hub, accountID, after string) ([]eventhub.Event, string, string) {
	if hub == nil {
		return nil, "replay_unavailable", ""
	}
	epoch := hub.BootEpoch()
	events, err := hub.Replay(ctx, accountID, after, replaypostgres.ReplayLimit)
	if err == nil {
		return events, "", epoch
	}
	switch {
	case errors.Is(err, replaypostgres.ErrDifferentEpoch):
		return nil, "server_restart", epoch
	case errors.Is(err, replaypostgres.ErrExpiredCursor):
		return nil, "cursor_expired", epoch
	case errors.Is(err, replaypostgres.ErrInvalidCursor):
		return nil, "cursor_invalid", epoch
	case errors.Is(err, replaypostgres.ErrReplayOverflow):
		return nil, "replay_limit", epoch
	default:
		return nil, "replay_unavailable", epoch
	}
}

type replayKey struct{ kind, id string }

func writeAuthorizedReplay(ctx context.Context, connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, hub *eventhub.Hub, epoch string, events []eventhub.Event, replayedIDs map[replayKey]struct{}, newID Identifier, now Clock, observer ConnectionObserver) (bool, bool) {
	for _, event := range events {
		if !hub.ContinuityAt(epoch) {
			observeReconnectOutcome(observer, "resync_required")
			return writeEvent(ctx, connection, newID, now, "connection.resync_required", map[string]any{"reason": "replay_unavailable"}), false
		}
		if !privateEventSessionValid(authenticator, cookie, subscription, observer) {
			observeReconnectOutcome(observer, "rejected")
			_ = connection.Close(websocket.StatusPolicyViolation, "session is no longer valid")
			return false, false
		}
		allowed, err := hub.Authorize(ctx, subscription.AccountID(), event)
		if err != nil {
			observeReconnectOutcome(observer, "resync_required")
			return writeEvent(ctx, connection, newID, now, "connection.resync_required", map[string]any{"reason": "replay_unavailable"}), false
		}
		if !allowed || !subscription.AllowsKind(event.Kind) {
			continue
		}
		if subscription.Supports("flow_tracing_v1") {
			event = hub.Correlate(ctx, subscription.AccountID(), event)
		}
		if err := wsjson.Write(ctx, connection, event); err != nil {
			return false, false
		}
		replayedIDs[replayKey{event.Kind, event.EventID}] = struct{}{}
	}
	return true, true
}

func observeReconnectOutcome(observer ConnectionObserver, outcome string) {
	if metrics, ok := observer.(interface{ ObserveRealtimeReconnectOutcome(string) }); ok {
		metrics.ObserveRealtimeReconnectOutcome(outcome)
	}
}
