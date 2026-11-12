package observe_resources

import (
	"errors"
	"testing"
)

func TestGuardFailureCategoriesAreBounded(t *testing.T) {
	cases := []struct {
		err  error
		want string
	}{
		{ErrUnavailable, "unavailable"}, {ErrDenied, "denied"},
		{ErrInvalid, "invalid_snapshot"}, {ErrForeign, "foreign_target"},
		{ErrStale, "stale_snapshot"}, {ErrThreshold, "resource_threshold"},
		{errors.New("private details"), "unknown"},
	}
	for _, item := range cases {
		if got := Category(item.err); got != item.want {
			t.Fatalf("category %q", got)
		}
	}
}
