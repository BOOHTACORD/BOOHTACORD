package rostermatrix

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"

	"voice-platform/backend/internal/load/validate_target"
)

// OpenLegacy is restricted to the owned pre-cutover fixture for comparison.
func OpenLegacy(ctx context.Context, client *http.Client, origin, stream string) (io.ReadCloser, error) {
	if validate_target.Loopback(origin, true) != nil {
		return nil, errors.New("legacy target must be loopback TLS")
	}
	path := ""
	switch stream {
	case "roster":
		path = "/api/v1/voice/rosters/events"
	case "maintenance":
		path = "/api/v1/maintenance/events"
	default:
		return nil, errors.New("unknown legacy stream")
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, origin+path, nil)
	if err != nil {
		return nil, errors.New("invalid legacy request")
	}
	request.Header.Set("Origin", origin)
	request.Header.Set("Accept", "text/event-stream")
	streamClient := *noRedirect(client)
	streamClient.Timeout = 0
	if stream == "maintenance" {
		streamClient.Jar = nil
	}
	response, err := streamClient.Do(request)
	if err != nil {
		return nil, errors.New("legacy stream connection failed")
	}
	if response.StatusCode != http.StatusOK || strings.TrimSpace(strings.Split(response.Header.Get("Content-Type"), ";")[0]) != "text/event-stream" {
		response.Body.Close()
		return nil, errors.New("legacy stream rejected")
	}
	return response.Body, nil
}
