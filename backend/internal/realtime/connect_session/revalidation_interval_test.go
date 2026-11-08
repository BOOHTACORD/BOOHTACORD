package connectsession

import (
	"testing"
	"time"
)

func TestRevalidationInterval(t *testing.T) {
	for _, tc := range []struct {
		name        string
		input, want time.Duration
	}{
		{"default", 0, 10 * time.Second},
		{"negative", -time.Second, 10 * time.Second},
		{"excessive", time.Hour, 10 * time.Second},
		{"maximum", 10 * time.Second, 10 * time.Second},
		{"shorter", time.Millisecond, time.Millisecond},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := boundedRevalidationInterval(tc.input); got != tc.want {
				t.Fatalf("boundedRevalidationInterval(%s) = %s, want %s", tc.input, got, tc.want)
			}
		})
	}
}
