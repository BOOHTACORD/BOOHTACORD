package listconnectedparticipantsapi

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type deadlineListerFunc func(context.Context, string) (roster.Result, error)

func (f deadlineListerFunc) List(ctx context.Context, s string) (roster.Result, error) {
	return f(ctx, s)
}
func TestRESTSnapshotBoundsDatabaseStagesAndReleasesContext(t *testing.T) {
	var snapshot context.Context
	handler := NewHandler(deadlineListerFunc(func(ctx context.Context, _ string) (roster.Result, error) {
		snapshot = ctx
		deadline, ok := ctx.Deadline()
		if !ok {
			t.Error("REST roster database stages lack deadline")
		} else if left := time.Until(deadline); left <= 0 || left > 5*time.Second {
			t.Error("REST snapshot exceeds existing five-second SSE budget")
		}
		return roster.Result{Channels: []roster.ChannelRoster{}}, nil
	}))
	request := httptest.NewRequest(http.MethodGet, "/api/v1/voice/participants", nil)
	request = request.WithContext(sessionapi.WithPrincipal(request.Context(), auth.Principal{AccountID: "test-actor"}))
	handler.ServeHTTP(httptest.NewRecorder(), request)
	if snapshot.Err() != context.Canceled {
		t.Error("completed snapshot context not released")
	}
	if request.Context().Err() != nil {
		t.Error("original request unexpectedly cancelled")
	}
}
