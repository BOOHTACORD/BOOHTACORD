package app

import (
	runtimeconfig "voice-platform/backend/internal/config/runtime"
	"voice-platform/backend/internal/database/pool"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	"voice-platform/backend/internal/identity/password"
	failures "voice-platform/backend/internal/identity/track_login_failures"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

func configureMetrics(configuration runtimeconfig.Config) (*httpmetrics.Recorder, *pool.Metrics, error) {
	metrics := httpmetrics.New()
	if err := metrics.RegisterCollector(ratelimit.NewCollector(map[string]*ratelimit.Limiter{
		"registration": configuration.RegistrationLimiter, "login_source": configuration.LoginLimiter, "login_deployment": configuration.LoginDeploymentLimiter,
		"password_reset": configuration.PasswordResetLimiter,
		"upload_source":  configuration.UploadLimiter, "upload_account": configuration.UploadAccountLimiter,
		"upload_deployment": configuration.UploadDeploymentLimiter, "telemetry": configuration.TelemetryLimiter,
	})); err != nil {
		return nil, nil, err
	}
	poolMetrics := pool.NewMetrics()
	if err := metrics.RegisterCollector(admitlogin.NewCollector(configuration.LoginAdmission)); err != nil {
		return nil, nil, err
	}
	if err := metrics.RegisterCollector(failures.NewCollector(configuration.LoginFailures)); err != nil {
		return nil, nil, err
	}
	if err := metrics.RegisterCollector(password.NewCollector()); err != nil {
		return nil, nil, err
	}
	if err := metrics.RegisterCollector(poolMetrics); err != nil {
		return nil, nil, err
	}
	return metrics, poolMetrics, nil
}
