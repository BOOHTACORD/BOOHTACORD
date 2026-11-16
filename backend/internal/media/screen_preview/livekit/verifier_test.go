package screenpreviewlivekit

import (
	"context"
	"encoding/json"
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

func TestCurrentPublicationRequiresValidMatchingScreenDescriptor(t *testing.T) {
	channelID, leaseID := uuid.NewString(), uuid.NewString()
	ownerAccountID := uuid.NewString()
	roomID := "voice:" + channelID
	descriptor := `{"schema_version":1,"scope":{"origin_id":"https://voice.example.test","account_id":"` + ownerAccountID + `","room_id":"` + roomID + `","media_session_id":"session-a","publication_generation":4,"operation_revision":7},"mode":"text","publisher_state":"sharing","viewer_state":"idle","requested_profile_id":"P1080_30","effective_profile":{"capture":{"max_width":1920,"max_height":1080,"max_fps":30},"encoding":{"codec":null,"layers":[{"rid":null,"width":1920,"height":1080,"max_fps":30,"max_bitrate_bps":2000000,"scale_down_by":1,"active":true}]}},"layer_topology":"single-layer","profile_revision":1,"capabilities":{"live_update":true,"republish_without_recapture":true,"simulcast":false},"reason_codes":["user-request"]}`
	body, err := json.Marshal(map[string]any{"participants": []any{map[string]any{
		"identity": "voice-lease:" + leaseID, "state": "ACTIVE",
		"attributes": map[string]string{"boohtacord.screen-share.v1": descriptor},
		"tracks":     []any{map[string]any{"sid": "screen-track-1", "type": "VIDEO", "source": "SCREEN_SHARE", "muted": false}},
	}}})
	if err != nil {
		t.Fatal(err)
	}
	transport := roundTripFunc(func(request *http.Request) (*http.Response, error) {
		return jsonResponse(request, string(body)), nil
	})
	client, err := New(Config{URL: "http://livekit.test", APIKey: "api-key", APISecret: "api-secret", HTTPTransport: transport})
	if err != nil {
		t.Fatal(err)
	}
	publication, err := client.CurrentPublication(context.Background(), channelID, leaseID, ownerAccountID)
	if err != nil || publication.TrackSID != "screen-track-1" || publication.Scope.MediaSessionID != "session-a" || publication.Scope.PublicationGeneration != 4 {
		t.Fatalf("publication=%+v err=%v", publication, err)
	}
	if _, err := client.CurrentPublication(context.Background(), channelID, leaseID, uuid.NewString()); !errors.Is(err, ErrNoPublication) {
		t.Fatalf("cross-account descriptor error=%v", err)
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
