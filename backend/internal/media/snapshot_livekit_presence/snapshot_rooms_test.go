package snapshotlivekitpresence

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestSnapshotRoomsOnlyReturnsActiveLeasesFromExactRequestedRooms(t *testing.T) {
	roomID := strings.TrimPrefix(testRoom, "voice:")
	emptyID := "22222222-2222-4222-8222-222222222222"
	activeLease := "33333333-3333-4333-8333-333333333333"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		claims := verifyGrant(t, request.Header.Get("Authorization"))
		writer.Header().Set("Content-Type", "application/json")
		switch request.URL.Path {
		case "/twirp/livekit.RoomService/ListRooms":
			if !claims.Video.RoomList || claims.Video.RoomAdmin || !strings.Contains(readBody(t, request), `"voice:`+emptyID+`"`) {
				t.Fatal("room list not exact or least privileged")
			}
			_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"}]}`))
		case "/twirp/livekit.RoomService/ListParticipants":
			if !claims.Video.RoomAdmin || claims.Video.Room != testRoom || claims.Video.RoomList {
				t.Fatal("participants grant not room-scoped")
			}
			_, _ = writer.Write([]byte(`{"participants":[` +
				`{"identity":"voice-lease:` + activeLease + `","state":"ACTIVE","attributes":{"boohtacord.voice.deafened.v1":"true"},"tracks":[{"type":"VIDEO","source":"SCREEN_SHARE"},{"type":"AUDIO","source":"MICROPHONE","muted":true}]},` +
				`{"identity":"voice-lease:44444444-4444-4444-8444-444444444444","state":"JOINED"},` +
				`{"identity":"voice-lease:55555555-5555-4555-8555-555555555555","state":"DISCONNECTED"},` +
				`{"identity":"system:agent","state":"ACTIVE"}]}`))
		default:
			t.Fatalf("unexpected RoomService path %q", request.URL.Path)
		}
	}))
	defer server.Close()
	client, _ := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	result, err := client.SnapshotRooms(context.Background(), []string{roomID, emptyID})
	if err != nil || len(result) != 1 || len(result[roomID]) != 1 || result[roomID][0].LeaseID != activeLease || !result[roomID][0].ScreenSharing || !result[roomID][0].MicrophoneMuted {
		t.Fatalf("SnapshotRooms() = %+v, %v", result, err)
	}
	if !result[roomID][0].Deafened {
		t.Fatal("snapshot did not preserve remote deafen")
	}
}

func TestSnapshotRoomsFailsClosedOnPrivateRoomError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "application/json")
		if strings.HasSuffix(request.URL.Path, "/ListRooms") {
			_, _ = writer.Write([]byte(`{"rooms":[{"name":"` + testRoom + `"}]}`))
			return
		}
		writer.WriteHeader(http.StatusServiceUnavailable)
		_, _ = writer.Write([]byte(`{"code":"unavailable","msg":"private failure"}`))
	}))
	defer server.Close()
	client, _ := New(Config{URL: server.URL, APIKey: "test-key", APISecret: "test-secret"})
	result, err := client.SnapshotRooms(context.Background(), []string{strings.TrimPrefix(testRoom, "voice:")})
	if result != nil || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("SnapshotRooms() = %+v, %v", result, err)
	}
}
