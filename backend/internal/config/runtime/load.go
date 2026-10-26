package runtimeconfig

import (
	"fmt"
	"net/http"
	"strings"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	centralexport "voice-platform/backend/internal/observability/central_export"

	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
	removelivekitparticipant "voice-platform/backend/internal/media/remove_livekit_participant"
	snapshotlivekitpresence "voice-platform/backend/internal/media/snapshot_livekit_presence"
	admitconnection "voice-platform/backend/internal/realtime/admit_connection"
	"voice-platform/backend/internal/security/origin_check"
	"voice-platform/backend/internal/security/rate_limit"
	admitupload "voice-platform/backend/internal/storage/admit_upload"
)

type Config struct {
	Notifications                                                                NotificationOptions
	NotificationsAvailable                                                       bool
	Address, DatabaseURL, LiveKitAPIKey, LiveKitAPISecret, LiveKitPrivateHTTPURL string
	PublicOrigin                                                                 string
	ClientUpdateCatalogPath                                                      string
	ClientUpdateAllowedHosts                                                     []string
	OriginMiddleware                                                             func(http.Handler) http.Handler
	CredentialSigner                                                             livekitcredential.Signer
	RoomRemover                                                                  removelivekitparticipant.Client
	MediaSnapshot                                                                snapshotlivekitpresence.Client
	RegistrationLimiter                                                          *ratelimit.Limiter
	LoginLimiter                                                                 *ratelimit.Limiter
	LoginAdmission                                                               *admitlogin.Budget
	PasswordResetLimiter                                                         *ratelimit.Limiter
	UploadLimiter                                                                *ratelimit.Limiter
	UploadAccountLimiter                                                         *ratelimit.Limiter
	UploadDeploymentLimiter                                                      *ratelimit.Limiter
	TelemetryLimiter                                                             *ratelimit.Limiter
	TelemetryEndpoint                                                            string
	TelemetryAuth                                                                string
	CausalKey                                                                    string
	CentralTelemetry                                                             *centralexport.Runtime
	AttachmentRoot                                                               string
	TrustedProxyCIDRs                                                            []string
	RealtimeConnectionLimiter                                                    *admitconnection.Limiter
	UploadAdmissionLimiter                                                       *admitupload.Limiter
}

func Load(getenv func(string) string) (Config, error) {
	configuration := Config{PublicOrigin: getenv("PUBLIC_ORIGIN"), AttachmentRoot: getenv("ATTACHMENTS_DIRECTORY"), TrustedProxyCIDRs: splitHosts(getenv("TRUSTED_PROXY_CIDRS"))}
	var err error
	if _, err := notificationAvailability(getenv("NOTIFICATION_WEB_ENABLED")); err != nil {
		return Config{}, fmt.Errorf("NOTIFICATION_WEB_ENABLED must be true or false")
	}
	configuration.Notifications = notificationOptions(getenv)
	configuration.NotificationsAvailable, err = notificationAvailability(getenv("NOTIFICATIONS_AVAILABLE"))
	if err != nil {
		return Config{}, err
	}
	configuration.OriginMiddleware, err = origincheck.New(configuration.PublicOrigin)
	if err != nil {
		return Config{}, fmt.Errorf("configure origin check: %w", err)
	}
	configuration.CredentialSigner, err = livekitcredential.New(livekitcredential.Config{URL: getenv("LIVEKIT_PUBLIC_WS_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit credential signer: %w", err)
	}
	configuration.RoomRemover, err = removelivekitparticipant.New(removelivekitparticipant.Config{URL: getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit room service: %w", err)
	}
	configuration.MediaSnapshot, err = snapshotlivekitpresence.New(snapshotlivekitpresence.Config{URL: getenv("LIVEKIT_PRIVATE_HTTP_URL"), APIKey: getenv("LIVEKIT_API_KEY"), APISecret: getenv("LIVEKIT_API_SECRET")})
	if err != nil {
		return Config{}, fmt.Errorf("configure livekit media snapshot: %w", err)
	}
	if err = configureAdmission(&configuration); err != nil {
		return Config{}, err
	}
	if configuration.AttachmentRoot == "" {
		return Config{}, fmt.Errorf("ATTACHMENTS_DIRECTORY is required")
	}
	configuration.TelemetryEndpoint = getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
	if configuration.TelemetryEndpoint == "" {
		if base := strings.TrimRight(getenv("OTEL_EXPORTER_OTLP_ENDPOINT"), "/"); base != "" {
			configuration.TelemetryEndpoint = base + "/v1/traces"
		}
	}
	configuration.TelemetryAuth = getenv("OTEL_INGEST_AUTH")
	configuration.ClientUpdateCatalogPath = getenv("CLIENT_UPDATE_CATALOG_PATH")
	if configuration.ClientUpdateCatalogPath == "" {
		configuration.ClientUpdateCatalogPath = "/etc/boohtacord/client-updates/catalog.json"
	}
	configuration.ClientUpdateAllowedHosts = splitHosts(getenv("CLIENT_UPDATE_ALLOWED_HOSTS"))
	if len(configuration.ClientUpdateAllowedHosts) == 0 {
		configuration.ClientUpdateAllowedHosts = publicHost(configuration.PublicOrigin)
	}
	configuration.Address = getenv("API_ADDR")
	if configuration.Address == "" {
		configuration.Address = ":8080"
	}
	configuration.DatabaseURL = getenv("DATABASE_URL")
	configuration.LiveKitPrivateHTTPURL = getenv("LIVEKIT_PRIVATE_HTTP_URL")
	configuration.LiveKitAPIKey = getenv("LIVEKIT_API_KEY")
	configuration.LiveKitAPISecret = getenv("LIVEKIT_API_SECRET")
	return configuration, nil
}

func splitHosts(raw string) []string {
	var result []string
	for _, value := range strings.Split(raw, ",") {
		if host := strings.TrimSpace(value); host != "" {
			result = append(result, host)
		}
	}
	return result
}

func publicHost(raw string) []string {
	request, err := http.NewRequest(http.MethodGet, raw, nil)
	if err != nil || request.URL.Hostname() == "" {
		return nil
	}
	return []string{request.URL.Hostname()}
}
