package app

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/app/lifecycle"
	publicrealtime "voice-platform/backend/internal/app/public_realtime"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	maintenance "voice-platform/backend/internal/maintenance/admission"
	maintenancepostgres "voice-platform/backend/internal/maintenance/admission/postgres"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
)

func startPublicRealtime(ctx context.Context, database *pgxpool.Pool, config runtimeconfig.Config) (http.Handler, *observestate.Observer, lifecycle.Stop, error) {
	service := maintenance.New(maintenancepostgres.New(maintenancepostgres.NewPoolDatabase(database)))
	return publicrealtime.StartShared(ctx, service, config.PublicOrigin, config.TrustedProxyCIDRs)
}
