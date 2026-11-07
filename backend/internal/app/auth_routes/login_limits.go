package authroutes

import (
	"net/http"
	runtimeconfig "voice-platform/backend/internal/config/runtime"
)

// loginLimits applies the same budgets to every login before account work.
func loginLimits(configuration runtimeconfig.Config, next http.Handler) http.Handler {
	next = configuration.LoginDeploymentLimiter.MiddlewareFor(next, func(*http.Request) string { return "deployment" })
	return configuration.LoginLimiter.Middleware(next)
}
