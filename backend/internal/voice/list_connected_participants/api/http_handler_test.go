package listconnectedparticipantsapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	authenticatesession "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
)

type listerStub struct {
	result listconnectedparticipants.Result
	err    error
	actor  string
}

func (stub *listerStub) List(_ context.Context, actor string) (listconnectedparticipants.Result, error) {
	stub.actor = actor
	return stub.result, stub.err
}
func (stub *listerStub) ListV2(ctx context.Context, actor string) (listconnectedparticipants.ResultV2, error) {
	result, err := stub.List(ctx, actor)
	if err != nil {
		return listconnectedparticipants.ResultV2{}, err
	}
	out := listconnectedparticipants.ResultV2{Channels: make([]listconnectedparticipants.ChannelRosterV2, 0, len(result.Channels))}
	for _, channel := range result.Channels {
		item := listconnectedparticipants.ChannelRosterV2{ChannelID: channel.ChannelID, Participants: make([]listconnectedparticipants.ParticipantV2, 0, len(channel.Participants))}
		for _, member := range channel.Participants {
			item.Participants = append(item.Participants, listconnectedparticipants.ParticipantV2{AccountID: member.AccountID, DisplayName: member.DisplayName, ScreenSharing: member.ScreenSharing, MicrophoneMuted: member.MicrophoneMuted, Deafened: member.Deafened})
		}
		out.Channels = append(out.Channels, item)
	}
	return out, nil
}

func TestHandlerReturnsProtectedUncachedRosterWithoutJoiningVoice(t *testing.T) {
	stub := &listerStub{result: listconnectedparticipants.Result{Channels: []listconnectedparticipants.ChannelRoster{{
		ChannelID: "11111111-1111-4111-8111-111111111111", Participants: []listconnectedparticipants.Participant{{AccountID: "22222222-2222-4222-8222-222222222222", DisplayName: "Мария", ScreenSharing: true}},
	}}}}
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/participants", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "33333333-3333-4333-8333-333333333333"}))
	recorder := httptest.NewRecorder()
	NewHandler(stub).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || recorder.Header().Get("Cache-Control") != "no-store" || stub.actor != "33333333-3333-4333-8333-333333333333" || !strings.Contains(recorder.Body.String(), `"screen_sharing":true`) || !strings.Contains(recorder.Body.String(), `"display_name":"Мария"`) || strings.Contains(recorder.Body.String(), `"deafened"`) {
		t.Fatalf("status=%d headers=%v body=%s actor=%s", recorder.Code, recorder.Header(), recorder.Body.String(), stub.actor)
	}
}

func TestV2HandlerAddsDeafenedStatus(t *testing.T) {
	stub := &listerStub{result: listconnectedparticipants.Result{Channels: []listconnectedparticipants.ChannelRoster{{ChannelID: "11111111-1111-4111-8111-111111111111", Participants: []listconnectedparticipants.Participant{{AccountID: "22222222-2222-4222-8222-222222222222", DisplayName: "Мария", Deafened: true}}}}}}
	request := httptest.NewRequest(http.MethodGet, "/api/v2/voice/participants", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "33333333-3333-4333-8333-333333333333"}))
	recorder := httptest.NewRecorder()
	NewV2Handler(stub).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), `"deafened":true`) {
		t.Fatalf("status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}

func TestHandlerRejectsMissingPrincipalAndFailsClosedOnPrivatePresence(t *testing.T) {
	stub := &listerStub{}
	recorder := httptest.NewRecorder()
	NewHandler(stub).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/api/v1/voice/participants", nil))
	if recorder.Code != http.StatusInternalServerError || stub.actor != "" {
		t.Fatalf("missing principal status=%d", recorder.Code)
	}
	stub.err = listconnectedparticipants.ErrPresenceUnavailable
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/participants", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "33333333-3333-4333-8333-333333333333"}))
	recorder = httptest.NewRecorder()
	NewHandler(stub).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusServiceUnavailable || !strings.Contains(recorder.Body.String(), `"code":"VOICE_PRESENCE_UNAVAILABLE"`) {
		t.Fatalf("private failure status=%d body=%s", recorder.Code, recorder.Body.String())
	}
	stub.err = errors.New("db failed")
	recorder = httptest.NewRecorder()
	NewHandler(stub).ServeHTTP(recorder, request)
	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("database failure status=%d", recorder.Code)
	}
}
