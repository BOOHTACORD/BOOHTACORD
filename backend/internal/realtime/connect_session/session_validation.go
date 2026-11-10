package connectsession

import (
	"context"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func isPrivateDirectMessageEvent(kind string) bool {
	switch kind {
	case "direct_message.message_created", "direct_message.message_updated", "direct_message.message_deleted", "direct_message.reactions_updated":
		return true
	default:
		return false
	}
}

func privateEventSessionValid(authenticator sessionapi.Authenticator, cookie *http.Cookie, subscription *eventhub.Subscription, observers ...ConnectionObserver) bool {
	if authenticator == nil || cookie == nil || subscription == nil || subscription.AccountID() == "" {
		return false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	started := time.Now()
	principal, err := authenticator.Authenticate(ctx, cookie.Value)
	observeRevalidation(firstObserver(observers), time.Since(started), err == nil && principal.AccountID == subscription.AccountID())
	return err == nil && principal.AccountID == subscription.AccountID()
}

func firstObserver(observers []ConnectionObserver) ConnectionObserver {
	if len(observers) == 0 {
		return nil
	}
	return observers[0]
}

func observeRevalidation(observer ConnectionObserver, duration time.Duration, valid bool) {
	if metrics, ok := observer.(interface{ ObserveRealtimeSessionRevalidation(time.Duration, bool) }); ok {
		metrics.ObserveRealtimeSessionRevalidation(duration, valid)
	}
}

func writeEvent(context context.Context, connection *websocket.Conn, newID Identifier, now Clock, kind string, payload map[string]any) bool {
	return wsjson.Write(context, connection, Event{EventID: newID(), Kind: kind, OccurredAt: now().UTC(), Payload: payload}) == nil
}
