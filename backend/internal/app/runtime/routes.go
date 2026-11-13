package app

import (
	"context"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.opentelemetry.io/otel"
	"log/slog"
	"net/http"
	archivetextroutes "voice-platform/backend/internal/app/archive_text_routes"
	authroutes "voice-platform/backend/internal/app/auth_routes"
	authorizationroutes "voice-platform/backend/internal/app/authorization_routes"
	channelsroutes "voice-platform/backend/internal/app/channels_routes"
	chatroutes "voice-platform/backend/internal/app/chat_routes"
	guildroutes "voice-platform/backend/internal/app/guild_routes"
	identityroutes "voice-platform/backend/internal/app/identity_routes"
	"voice-platform/backend/internal/app/lifecycle"
	mediaroutes "voice-platform/backend/internal/app/media_routes"
	messagesocialroutes "voice-platform/backend/internal/app/message_social_routes"
	notificationroutes "voice-platform/backend/internal/app/notification_routes"
	observabilityroutes "voice-platform/backend/internal/app/observability_routes"
	storageroutes "voice-platform/backend/internal/app/storage_routes"
	voicesoundroutes "voice-platform/backend/internal/app/voice_sound_routes"
	clientupdates "voice-platform/backend/internal/client_updates/catalog"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	observeusage "voice-platform/backend/internal/identity/observe_usage"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	authorizelivekitsignal "voice-platform/backend/internal/media/authorize_livekit_signal"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	installationapi "voice-platform/backend/internal/observability/installation/api"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	"voice-platform/backend/internal/security/request_id"
	reserve "voice-platform/backend/internal/storage/reserve_upload_space"
	soundpreferences "voice-platform/backend/internal/voice/sound_preferences"
	soundpostgres "voice-platform/backend/internal/voice/sound_preferences/postgres"
)

func routes(ctx context.Context, resources *lifecycle.Stack, database, sessionDatabase *pgxpool.Pool, configuration runtimeconfig.Config, events *eventhub.Hub, metrics *httpmetrics.Recorder, updates clientupdates.Provider, usage *observeusage.Tracker, previews screenpreview.Store, screenViewers *presencememory.Store, publicRealtime http.Handler, maintenanceObserver *observestate.Observer) (http.Handler, screenpreview.Service, error) {
	if events != nil {
		key := configuration.CausalKey
		if configuration.CentralTelemetry == nil {
			key = configuration.TelemetryAuth
		}
		events.SetTelemetryKey(key)
	}
	mux := http.NewServeMux()
	mux.Handle("GET /api/v1/public/realtime", publicRealtime)
	mux.Handle("/api/v1/client-updates", clientupdates.Handler(updates, metrics))
	lifecycle := guildlifecycle.New(otel.Tracer("boohtacord/guild"), otel.Meter("boohtacord/guild"), metrics)
	auth := authroutes.Register(mux, database, sessionDatabase, configuration, events, usage, lifecycle)
	sessionService, maintenanceService := auth.Sessions, auth.Maintenance
	notificationroutes.Register(mux, database, sessionService, configuration.NotificationsAvailable, events)
	voicesoundroutes.Register(mux, soundpreferences.New(soundpostgres.New(database)), sessionService)
	if err := voicesoundroutes.RegisterJoinSounds(mux, database, sessionService, configuration.JoinSoundProcessorURL); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure join sound processor: %w", err)
	}
	notificationroutes.RegisterDevices(mux, database, sessionService, configuration)
	notificationroutes.RegisterActivation(mux, database, sessionService, configuration)
	notificationroutes.RegisterReferences(mux, database, sessionService, configuration)
	guildroutes.Register(mux, database, sessionService, events, lifecycle)
	authorizationroutes.ConfigureRolePermissionRoutes(mux, database, sessionService, events)
	if err := mediaroutes.ConfigureMediaRevocationRoutes(mux, database, authorizelivekitsignal.Config{APIKey: configuration.LiveKitAPIKey, APISecret: configuration.LiveKitAPISecret}, maintenanceService); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure media admission: %w", err)
	}
	if err := observabilityroutes.RegisterVoiceMediaMetrics(metrics, configuration.MediaSnapshot); err != nil {
		return nil, screenpreview.Service{}, err
	}
	observabilityroutes.ConfigureStatusRoutes(mux, maintenanceService, metrics)
	channelsroutes.ConfigureChannelRoutes(mux, database, sessionService, events)
	channelsroutes.ConfigureVoiceClosureRoutes(mux, database, sessionService, configuration.MediaSnapshot)
	rosterFactory, stopRoster, err := mediaroutes.StartVoiceParticipantRoutes(ctx, mux, database, sessionService, configuration.MediaSnapshot, metrics, configuration.LiveKitAPIKey, configuration.LiveKitAPISecret)
	if err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure voice roster: %w", err)
	}
	resources.Add(stopRoster)
	chatroutes.ConfigureChatRoutes(mux, database, sessionService, events)
	chatroutes.ConfigureRealtimeRoutesWithRoster(mux, sessionService, metrics, events, configuration.RealtimeConnectionLimiter, maintenanceObserver, rosterFactory)
	if err := storageroutes.ConfigureStorageRoutes(mux, database, sessionService, configuration.AttachmentRoot, configuration.UploadLimiter, configuration.UploadAccountLimiter, configuration.UploadDeploymentLimiter, configuration.UploadAdmissionLimiter, metrics, func(space reserve.Space, manager *reserve.Manager) {
		observabilityroutes.ConfigureReadinessRoutes(mux, database, sessionService, configuration.MediaSnapshot, space, manager)
	}); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure attachment routes: %w", err)
	}
	if err := identityroutes.ConfigureProfileAdminRoutes(mux, database, sessionService, configuration, events); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure profile routes: %w", err)
	}
	if err := archivetextroutes.Register(mux, database, sessionService, events, configuration.AttachmentRoot); err != nil {
		return nil, screenpreview.Service{}, err
	}
	messagesocialroutes.Register(mux, database, sessionService, events)
	mediaroutes.ConfigureVoiceLeaseRoutes(mux, database, sessionService, maintenanceService)
	observabilityroutes.ConfigureClientScreenRoutes(mux, database, sessionService, metrics)
	observabilityroutes.ConfigureClientTelemetryRoutes(mux, sessionService, configuration)
	observabilityroutes.ConfigureInstallationRoutes(mux, sessionService, configuration)
	mediaroutes.ConfigureAdminVoiceRoutes(mux, database, sessionService)
	mediaroutes.ConfigureMediaCredentialRoutes(mux, database, sessionService, configuration.CredentialSigner)
	previewService, err := mediaroutes.ConfigureScreenPreviewRoutes(mux, database, sessionService, configuration.LiveKitPrivateHTTPURL, configuration.LiveKitAPIKey, configuration.LiveKitAPISecret, configuration.ScreenPreviewRoot, previews, events)
	if err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure private screen previews: %w", err)
	}
	if err := mediaroutes.ConfigureScreenViewerPresenceRoutes(mux, database, sessionService, configuration.LiveKitPrivateHTTPURL, configuration.LiveKitAPIKey, configuration.LiveKitAPISecret, screenViewers, events); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure screen viewer presence: %w", err)
	}
	if err := mediaroutes.ConfigureScreenDescriptorRoutes(mux, database, sessionService, configuration.PublicOrigin, configuration.LiveKitPrivateHTTPURL, configuration.LiveKitAPIKey, configuration.LiveKitAPISecret); err != nil {
		return nil, screenpreview.Service{}, fmt.Errorf("configure screen profile descriptor updates: %w", err)
	}
	return installationapi.Headers(requestid.Middleware(httpmetrics.LoggingMiddleware(slog.Default(), metrics.Middleware(tracehttp.Middleware(otel.Tracer("boohtacord/api"), mux, configuration.OriginMiddleware(mux)), mux))), configuration.CentralTelemetry), previewService, nil
}
