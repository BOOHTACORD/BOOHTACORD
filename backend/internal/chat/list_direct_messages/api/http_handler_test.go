package listdirectmessagesapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	support "voice-platform/backend/internal/support/contact"

	listdirectmessages "voice-platform/backend/internal/chat/list_direct_messages"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestHandlerListsOnlyCurrentPrincipalsDirectMessagesWithoutRoleBypass(t *testing.T) {
	var input listdirectmessages.Input
	handler := NewHandler(listerFunc(func(_ context.Context, value listdirectmessages.Input) (listdirectmessages.Result, error) {
		input = value
		return listdirectmessages.Result{DirectMessages: []listdirectmessages.DirectMessage{{ID: "22222222-2222-4222-8222-222222222222", OtherParticipantID: "33333333-3333-4333-8333-333333333333", OtherParticipantDisplayName: "Собеседник", UnreadCount: 3, FirstUnreadMessageID: "first-1"}}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/direct-messages", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), authenticatesession.Principal{AccountID: "11111111-1111-4111-8111-111111111111", Role: "ADMINISTRATOR"}))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK || input.ActorID != "11111111-1111-4111-8111-111111111111" || !strings.Contains(recorder.Body.String(), `"other_participant_display_name":"Собеседник"`) || !strings.Contains(recorder.Body.String(), `"unread_count":3`) || !strings.Contains(recorder.Body.String(), `"first_unread_message_id":"first-1"`) {
		t.Fatalf("status=%d input=%#v body=%q", recorder.Code, input, recorder.Body.String())
	}
}

type listerFunc func(context.Context, listdirectmessages.Input) (listdirectmessages.Result, error)

func (function listerFunc) List(context context.Context, input listdirectmessages.Input) (listdirectmessages.Result, error) {
	return function(context, input)
}

type supportFunc func(context.Context, string) (support.Contact, error)

func (f supportFunc) Resolve(ctx context.Context, actor string) (support.Contact, error) {
	return f(ctx, actor)
}
func TestSupportMetadataUsesAuthenticatedActorAndIgnoresClientSelection(t *testing.T) {
	const actor = "11111111-1111-4111-8111-111111111111"
	handler := NewHandler(listerFunc(func(context.Context, listdirectmessages.Input) (listdirectmessages.Result, error) {
		return listdirectmessages.Result{}, nil
	}), supportFunc(func(_ context.Context, id string) (support.Contact, error) {
		if id != actor {
			t.Fatal("support actor came from client")
		}
		return support.Contact{State: "available", Revision: 2, AccountID: "22222222-2222-4222-8222-222222222222"}, nil
	}))
	req := httptest.NewRequest("GET", "/api/v1/direct-messages?support_account_id=attacker", nil)
	req = req.WithContext(sessionapi.WithPrincipal(req.Context(), authenticatesession.Principal{AccountID: actor, Role: "MEMBER"}))
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, req)
	var result response
	if err := json.Unmarshal(recorder.Body.Bytes(), &result); err != nil || recorder.Code != 200 || result.SupportContact == nil || result.SupportContact.AccountID != "22222222-2222-4222-8222-222222222222" {
		t.Fatal("server support metadata missing")
	}
}
