package screenpreviewlivekit

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestCurrentTrackRequiresExactActiveScreenPublication(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	var requestPath, authorization string
	transport := roundTripFunc(func(request *http.Request) (*http.Response, error) {
		requestPath, authorization = request.URL.Path, request.Header.Get("Authorization")
		body := `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"screen-track-1","type":"VIDEO","source":"SCREEN_SHARE","muted":false}]}]}`
		return jsonResponse(request, body), nil
	})
	client, err := New(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	track, err := client.CurrentTrack(context.Background(), channelID, leaseID)
	if err != nil || track != "screen-track-1" {
		t.Fatalf("track = %q, err = %v", track, err)
	}
	if requestPath != "/twirp/livekit.RoomService/ListParticipants" || !strings.HasPrefix(authorization, "Bearer ") {
		t.Fatalf("RoomService request was not authenticated: %q %q", requestPath, authorization)
	}
}

func TestCurrentTrackFailsClosedForMissingMutedOrAmbiguousPublication(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	cases := map[string]string{
		"missing":   `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[]}]}`,
		"muted":     `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"a","type":"VIDEO","source":"SCREEN_SHARE","muted":true}]}]}`,
		"ambiguous": `{"participants":[{"identity":"voice-lease:` + leaseID + `","state":"ACTIVE","tracks":[{"sid":"a","type":"VIDEO","source":"SCREEN_SHARE"},{"sid":"b","type":"VIDEO","source":"SCREEN_SHARE"}]}]}`,
	}
	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			transport := roundTripFunc(func(request *http.Request) (*http.Response, error) { return jsonResponse(request, payload), nil })
			client, err := New(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", HTTPTransport: transport})
			if err != nil {
				t.Fatal(err)
			}
			if _, err := client.CurrentTrack(context.Background(), channelID, leaseID); !errors.Is(err, ErrNoPublication) {
				t.Fatalf("error = %v", err)
			}
		})
	}
}

func TestCurrentTrackRejectsInvalidIdentifiersAndUnavailableService(t *testing.T) {
	transport := roundTripFunc(func(*http.Request) (*http.Response, error) { return nil, errors.New("offline") })
	client, err := New(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := client.CurrentTrack(context.Background(), "not-a-channel", uuid.NewString()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("invalid channel error = %v", err)
	}
	if _, err := client.CurrentTrack(context.Background(), uuid.NewString(), uuid.NewString()); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("unavailable service error = %v", err)
	}
}

func jsonResponse(request *http.Request, body string) *http.Response {
	return &http.Response{
		StatusCode: http.StatusOK,
		Header:     http.Header{"Content-Type": []string{"application/json"}},
		Body:       io.NopCloser(strings.NewReader(body)),
		Request:    request,
	}
}
