package observe_resources

import "errors"

var (
	ErrUnavailable = errors.New("isolated resource guard unavailable")
	ErrDenied      = errors.New("isolated resource guard denied")
	ErrInvalid     = errors.New("invalid guard snapshot")
	ErrForeign     = errors.New("foreign deployment or dataset guard")
	ErrStale       = errors.New("stale guard snapshot")
	ErrThreshold   = errors.New("resource threshold exceeded")
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
	default:
		return "unknown"
	}
}
