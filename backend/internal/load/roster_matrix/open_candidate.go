package rostermatrix

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"strings"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/validate_target"
)

func OpenCandidate(ctx context.Context, client *http.Client, origin string) (*websocket.Conn, error) {
	return openSocket(ctx, client, origin, true)
}

func OpenBaseline(ctx context.Context, client *http.Client, origin string) (*websocket.Conn, error) {
	return openSocket(ctx, client, origin, false)
}

func openSocket(ctx context.Context, client *http.Client, origin string, candidate bool) (*websocket.Conn, error) {
	if validate_target.Loopback(origin, true) != nil {
		return nil, errors.New("candidate target must be loopback TLS")
	}
	capabilities := "role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1,notifications_v1"
	if candidate {
		capabilities += ",voice_roster_v1,maintenance_v1"
	}
	query := url.Values{"capabilities": {capabilities}}
	address := strings.Replace(origin, "https://", "wss://", 1) + "/api/v1/realtime?" + query.Encode()
	conn, response, err := websocket.Dial(ctx, address, &websocket.DialOptions{HTTPClient: noRedirect(client), HTTPHeader: http.Header{"Origin": {origin}}})
	if err != nil {
		if response != nil {
			response.Body.Close()
		}
		return nil, errors.New("fixture socket upgrade failed")
	}
	return conn, nil
}
