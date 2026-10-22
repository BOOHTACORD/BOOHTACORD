package senddirectmessageapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	send "voice-platform/backend/internal/chat/send_direct_message"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

type productPair bool

func (p productPair) ProductPair(context.Context, string, string) (bool, error) { return bool(p), nil }
func TestLegacyClientCannotPublishEvenWhenAnotherDeviceAlreadyConsented(t *testing.T) {
	for _, row := range []struct {
		product bool
		header  string
		status  int
	}{{true, "", 409}, {true, "v1", 201}, {false, "", 201}} {
		sends := 0
		handler := NewHandler(senderFunc(func(context.Context, send.Input) (send.Result, error) { sends++; return send.Result{}, nil }), productPair(row.product))
		request := httptest.NewRequest(http.MethodPost, "/api/v1/direct-messages/pair/messages", strings.NewReader(`{"body":"Synthetic support text"}`))
		request.SetPathValue("directMessageID", "22222222-2222-4222-8222-222222222222")
		request.Header.Set("X-Boohtacord-Support-Publication", row.header)
		request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "11111111-1111-4111-8111-111111111111"}))
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != row.status || (row.status == 409 && sends != 0) {
			t.Fatal("legacy publication boundary failed")
		}
	}
}
