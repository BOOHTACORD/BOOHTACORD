package voicesoundroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	s "voice-platform/backend/internal/voice/join_sound"
	api "voice-platform/backend/internal/voice/join_sound/api"
	downloadapi "voice-platform/backend/internal/voice/join_sound/download_api"
	store "voice-platform/backend/internal/voice/join_sound/postgres"
	processor "voice-platform/backend/internal/voice/join_sound/processor"
)

func RegisterJoinSounds(mux *http.ServeMux, database *pgxpool.Pool, auth session.Authenticator, endpoint string) error {
	var remote s.Processor
	if endpoint != "" {
		client, err := processor.NewRemote(endpoint)
		if err != nil {
			return err
		}
		remote = client
	}
	service := s.New(store.New(database), remote)
	handler := session.Require(auth)(api.NewHandler(service))
	mux.Handle("GET /api/v1/me/join-sound", handler)
	mux.Handle("POST /api/v1/me/join-sound", handler)
	mux.Handle("PATCH /api/v1/me/join-sound", handler)
	mux.Handle("DELETE /api/v1/me/join-sound", handler)
	mux.Handle("GET /api/v1/voice/join-sounds/{id}", session.Require(auth)(downloadapi.NewDownloadHandler(service)))
	return nil
}
