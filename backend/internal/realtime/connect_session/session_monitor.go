package connectsession

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/coder/websocket"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

// The monitor runs independently of the single application writer. The interval,
// lookup deadline and WebSocket close deadline leave time inside the 10 s budget.
func startSessionMonitor(parent context.Context, connection *websocket.Conn, authenticator sessionapi.Authenticator, cookie *http.Cookie, original auth.Principal, interval time.Duration, observer ConnectionObserver) context.CancelFunc {
	ctx, cancel := context.WithCancel(parent)
	if authenticator == nil || cookie == nil {
		return cancel
	}
	if interval > 1500*time.Millisecond {
		interval = 1500 * time.Millisecond
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				lookup, stop := context.WithTimeout(ctx, time.Second)
				started := time.Now()
				principal, err := authenticator.Authenticate(lookup, cookie.Value)
				stop()
				valid := err == nil && principal.AccountID == original.AccountID && principal.SessionDigest == original.SessionDigest
				observeRevalidation(observer, time.Since(started), valid)
				if ctx.Err() != nil {
					return
				}
				if !valid {
					status := websocket.StatusTryAgainLater
					reason := "session verification unavailable"
					if err == nil || errors.Is(err, auth.ErrUnauthenticated) {
						status, reason = websocket.StatusPolicyViolation, "session is no longer valid"
					}
					_ = connection.Close(status, reason)
					return
				}
			}
		}
	}()
	return cancel
}
