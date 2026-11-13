package authroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
)

func sessionServiceFor(database *pgxpool.Pool, usage *observeusage.Tracker) authenticatesession.Service {
	return authenticatesession.New(observeusage.TrackSessions(sessionpostgres.New(sessionpostgres.NewPoolDatabase(database)), usage))
}
