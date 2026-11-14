package setvoicedeafenlivekit

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/livekit/protocol/auth"
	setvoicedeafen "voice-platform/backend/internal/media/set_voice_deafen"
)

func TestPublishChangesOnlyTheWhitelistedAttributeAndUsesRoomScopedGrant(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/twirp/livekit.RoomService/UpdateParticipant" {
			t.Fatalf("path=%s", r.URL.Path)
		}
		const prefix = "Bearer "
		value := r.Header.Get("Authorization")
		if len(value) <= len(prefix) || value[:len(prefix)] != prefix {
			t.Fatal("missing server token")
		}
		parsed, err := auth.ParseAPIToken(value[len(prefix):])
		if err != nil {
			t.Fatal(err)
		}
		_, claims, err := parsed.Verify("secret")
		if err != nil || claims.Video == nil || !claims.Video.RoomAdmin || claims.Video.Room != "voice:22222222-2222-4222-8222-222222222222" || claims.Video.RoomList {
			t.Fatalf("grant=%+v", claims.Video)
		}
		var body map[string]json.RawMessage
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if len(body) != 3 || body["metadata"] != nil || body["name"] != nil || body["permission"] != nil {
			t.Fatalf("unexpected update fields: %s", body)
		}
		var attrs map[string]string
		if err := json.Unmarshal(body["attributes"], &attrs); err != nil {
			t.Fatal(err)
		}
		if len(attrs) != 1 || attrs[setvoicedeafen.Attribute] != "true" {
			t.Fatalf("attributes=%v", attrs)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"sid":"participant"}`))
	}))
	defer server.Close()
	writer, err := New(Config{URL: server.URL, APIKey: "key", APISecret: "secret"})
	if err != nil {
		t.Fatal(err)
	}
	if err := writer.Publish(context.Background(), "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", true); err != nil {
		t.Fatal(err)
	}
}
