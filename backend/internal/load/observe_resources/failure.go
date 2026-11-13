package observe_resources

import "errors"

var (
	ErrUnavailable         = errors.New("isolated resource guard unavailable")
	ErrDenied              = errors.New("isolated resource guard denied")
	ErrInvalid             = errors.New("invalid guard snapshot")
	ErrForeign             = errors.New("foreign deployment or dataset guard")
	ErrStale               = errors.New("stale guard snapshot")
	ErrThreshold           = errors.New("resource threshold exceeded")
	ErrFixtureVerification = errors.New("fixture verification unavailable")
	ErrResourceSnapshot    = errors.New("resource snapshot unavailable")
	ErrResourceMetrics     = errors.New("resource metrics unavailable")
	ErrMetricsTimeout      = errors.New("resource metrics timeout")
	ErrMetricsHTTP         = errors.New("resource metrics HTTP failure")
	ErrMetricsUnavailable  = errors.New("resource metrics connection unavailable")
	ErrMetricsInvalid      = errors.New("resource metrics invalid")
)

// Category exposes a fixed vocabulary without retaining error details.
func Category(err error) string {
	switch {
	case errors.Is(err, ErrUnavailable):
		return "unavailable"
	case errors.Is(err, ErrDenied):
		return "denied"
	case errors.Is(err, ErrInvalid):
		return "invalid_snapshot"
	case errors.Is(err, ErrForeign):
		return "foreign_target"
	case errors.Is(err, ErrStale):
		return "stale_snapshot"
	case errors.Is(err, ErrThreshold):
		return "resource_threshold"
	case errors.Is(err, ErrFixtureVerification):
		return "fixture_verification"
	case errors.Is(err, ErrResourceSnapshot):
		return "resource_snapshot"
	case errors.Is(err, ErrResourceMetrics):
		return "resource_metrics"
	case errors.Is(err, ErrMetricsTimeout):
		return "resource_metrics_timeout"
	case errors.Is(err, ErrMetricsHTTP):
		return "resource_metrics_http"
	case errors.Is(err, ErrMetricsUnavailable):
		return "resource_metrics_unavailable"
	case errors.Is(err, ErrMetricsInvalid):
		return "resource_metrics_invalid"
	default:
		return "unknown"
	}
}
