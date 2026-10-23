package authroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"net/http"
	"time"
	ownsessionroutes "voice-platform/backend/internal/app/own_session_routes"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/identity/admin_account"
	adminapi "voice-platform/backend/internal/identity/admin_account/api"
	adminpostgres "voice-platform/backend/internal/identity/admin_account/postgres"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	sessionpostgres "voice-platform/backend/internal/identity/authenticate_session/postgres"
	"voice-platform/backend/internal/identity/complete_password_reset"
	completeresetapi "voice-platform/backend/internal/identity/complete_password_reset/api"
	completeresetpostgres "voice-platform/backend/internal/identity/complete_password_reset/postgres"
	"voice-platform/backend/internal/identity/create_password_reset"
	createresetapi "voice-platform/backend/internal/identity/create_password_reset/api"
	createresetpostgres "voice-platform/backend/internal/identity/create_password_reset/postgres"
	"voice-platform/backend/internal/identity/login_user"
	loginapi "voice-platform/backend/internal/identity/login_user/api"
	loginpostgres "voice-platform/backend/internal/identity/login_user/postgres"
	"voice-platform/backend/internal/identity/logout_user"
	logoutapi "voice-platform/backend/internal/identity/logout_user/api"
	logoutpostgres "voice-platform/backend/internal/identity/logout_user/postgres"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
	publishpermissioninvalidation "voice-platform/backend/internal/identity/publish_permission_invalidation"
	"voice-platform/backend/internal/identity/register_user"
	registerapi "voice-platform/backend/internal/identity/register_user/api"
	welcomepostgres "voice-platform/backend/internal/identity/registration_welcome/postgres"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	maintenancepostgres "voice-platform/backend/internal/maintenance/admission/postgres"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

type Services struct {
	Sessions    authenticatesession.Service
	Maintenance maintenanceadmission.Service
}

func Register(mux *http.ServeMux, database *pgxpool.Pool, configuration runtimeconfig.Config, events *eventhub.Hub, usage *observeusage.Tracker, observers ...*guildlifecycle.Observer) Services {
	observer := guildlifecycle.New(otel.Tracer("boohtacord/guild"), otel.Meter("boohtacord/guild"), nil)
	if len(observers) > 0 {
		observer = observers[0]
	}
	registerService := registeruser.New(welcomepostgres.Repository{Database: database, Observer: observer, Events: events})
	loginRepository := loginpostgres.New(loginpostgres.NewPoolDatabase(database))
	loginService := loginuser.New(loginRepository, loginRepository)
	logoutService := logoutuser.New(logoutpostgres.New(logoutpostgres.NewPoolDatabase(database)))
	sessionService := authenticatesession.New(observeusage.TrackSessions(sessionpostgres.New(sessionpostgres.NewPoolDatabase(database)), usage))
	ownsessionroutes.Register(mux, database, sessionService, events)
	passwordResetService := completepasswordreset.New(completeresetpostgres.New(completeresetpostgres.NewPoolDatabase(database)))
	passwordResetCreator := createpasswordreset.New(createresetpostgres.New(createresetpostgres.NewPoolDatabase(database)), time.Now)
	accountAdministration := adminaccount.New(adminpostgres.New(adminpostgres.NewPoolDatabase(database)))
	maintenanceService := maintenanceadmission.New(maintenancepostgres.New(maintenancepostgres.NewPoolDatabase(database)))

	mux.Handle("POST /api/v1/auth/register", maintenanceadmission.Middleware(maintenanceService)(configuration.RegistrationLimiter.Middleware(registerapi.NewHandler(registerService))))
	mux.Handle("POST /api/v1/auth/login", maintenanceadmission.Middleware(maintenanceService)(configuration.LoginLimiter.Middleware(loginapi.NewHandlerWithAdmission(loginService, configuration.LoginAdmission))))
	mux.Handle("POST /api/v1/auth/logout", logoutapi.NewHandler(logoutService))
	mux.Handle("GET /api/v1/auth/session", sessionapi.Optional(sessionService)(sessionapi.CurrentHandler()))
	mux.Handle("POST /api/v1/auth/password-reset/complete", configuration.PasswordResetLimiter.Middleware(completeresetapi.NewHandler(passwordResetService)))
	mux.Handle("POST /api/v1/admin/password-reset-links", sessionapi.Require(sessionService)(sessionapi.RequireAdministrator(configuration.PasswordResetLimiter.Middleware(createresetapi.NewHandler(passwordResetCreator, configuration.PublicOrigin)))))
	adminAccountHandler := publishpermissioninvalidation.NewHandler(adminapi.NewHandler(accountAdministration), events)
	mux.Handle("PATCH /api/v1/admin/accounts/{accountID}", sessionapi.Require(sessionService)(sessionapi.RequireAdministrator(adminAccountHandler)))
	return Services{Sessions: sessionService, Maintenance: maintenanceService}
}
