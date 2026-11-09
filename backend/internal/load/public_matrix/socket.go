package publicmatrix

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/coder/websocket"
	"voice-platform/backend/internal/load/validate_target"
)

func Open(ctx context.Context, client *http.Client, origin string) (*websocket.Conn, error) {
	if client == nil || validate_target.Loopback(origin, true) != nil {
		return nil, errors.New("public target must be loopback TLS")
	}
	publicClient := *client
	publicClient.Jar = nil
	publicClient.CheckRedirect = func(*http.Request, []*http.Request) error { return errors.New("fixture redirect refused") }
	address := strings.Replace(origin, "https://", "wss://", 1) + "/api/v1/public/realtime"
	conn, response, err := websocket.Dial(ctx, address, &websocket.DialOptions{HTTPClient: &publicClient, HTTPHeader: http.Header{"Origin": {origin}}})
	if err != nil {
		if response != nil {
			response.Body.Close()
		}
		return nil, errors.New("public fixture upgrade failed")
	}
	return conn, nil
}
