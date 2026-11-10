package mediaroutes

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/app/lifecycle"
	voicerealtime "voice-platform/backend/internal/app/voice_realtime"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessiondelivery "voice-platform/backend/internal/identity/serialize_session_delivery"
	coalescepresence "voice-platform/backend/internal/media/coalesce_presence_snapshot"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
	authorizeroster "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
	rosterapi "voice-platform/backend/internal/voice/list_connected_participants/api"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
	watchroster "voice-platform/backend/internal/voice/watch_connected_participants"
)

func StartVoiceParticipantRoutes(ctx context.Context, mux *http.ServeMux, database *pgxpool.Pool, sessions authenticatesession.Service, presence snapshotlivekitpresence.Client, metrics *httpmetrics.Recorder, apiKey, apiSecret string) (connectsession.RosterFactory, lifecycle.Stop, error) {
	gate := coalescepresence.New(presence.WithObserver(metrics), metrics)
	repository := rosterpostgres.New(rosterpostgres.NewPoolDatabase(database))
	service := listconnectedparticipants.New(repository, gate, metrics)
	notifier := watchroster.NewNotifier(gate.Invalidate)
	delivery, err := sessiondelivery.New(database, 4, time.Second)
	if err != nil {
		return nil, nil, err
	}
	config := coordinator.Config{Workers: 4, MaxAccounts: 500, MaxSubscribers: 1000, MaxSnapshotBytes: 1 << 19, PollInterval: 5 * time.Second, ReadTimeout: 5 * time.Second}
	var observer voicerealtime.Observer
	if metrics != nil {
		observer = metrics
	}
	factory, stop, err := voicerealtime.Start(ctx, config, service, authorizeroster.New(sessions, repository, delivery), notifier, observer)
	if err != nil {
		return nil, nil, err
	}
	mux.Handle("GET /api/v1/voice/participants", sessionapi.Require(sessions)(rosterapi.NewHandler(service)))
	mux.Handle("POST /internal/livekit/roster", watchroster.NewWebhookHandler(apiKey, apiSecret, notifier))
	return factory.Open, stop, nil
}
