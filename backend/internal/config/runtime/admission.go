package runtimeconfig

import (
	"fmt"
	"time"
	admitlogin "voice-platform/backend/internal/identity/admit_login"

	admitconnection "voice-platform/backend/internal/realtime/admit_connection"
	"voice-platform/backend/internal/security/rate_limit"
	admitupload "voice-platform/backend/internal/storage/admit_upload"
)

func configureAdmission(configuration *Config) error {
	var err error
	trusted := configuration.TrustedProxyCIDRs
	makeLimiter := func(limit int, window time.Duration, sources int) (*ratelimit.Limiter, error) {
		return ratelimit.New(ratelimit.Config{Limit: limit, Window: window, MaxSources: sources, TrustedProxyCIDRs: trusted})
	}
	configuration.RegistrationLimiter, err = makeLimiter(5, 15*time.Minute, 10_000)
	if err == nil {
		configuration.LoginLimiter, err = makeLimiter(10, 5*time.Minute, 10_000)
	}
	if err == nil {
		configuration.LoginAdmission, err = admitlogin.New(admitlogin.Config{Limit: 8, Window: 30 * time.Second, MaxAccounts: 50_000})
	}
	if err == nil {
		configuration.PasswordResetLimiter, err = makeLimiter(5, 15*time.Minute, 10_000)
	}
	if err == nil {
		configuration.UploadLimiter, err = makeLimiter(200, 5*time.Minute, 10_000)
	}
	if err == nil {
		configuration.UploadAccountLimiter, err = makeLimiter(10, 5*time.Minute, 50_000)
	}
	if err == nil {
		configuration.UploadDeploymentLimiter, err = makeLimiter(5_000, 5*time.Minute, 1)
	}
	if err == nil {
		configuration.TelemetryLimiter, err = makeLimiter(120, time.Minute, 10_000)
	}
	if err != nil {
		return fmt.Errorf("configure rate limiter: %w", err)
	}
	configuration.RealtimeConnectionLimiter, err = admitconnection.New(admitconnection.Config{GlobalLimit: 500, AccountLimit: 5, SessionLimit: 2})
	if err != nil {
		return fmt.Errorf("configure realtime connection quotas: %w", err)
	}
	configuration.UploadAdmissionLimiter, err = admitupload.New(admitupload.Config{GlobalLimit: 16, AccountLimit: 2})
	if err != nil {
		return fmt.Errorf("configure upload concurrency quotas: %w", err)
	}
	return nil
}
