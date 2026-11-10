// Package connectpublic serves the anonymous maintenance realtime feed.
package connectpublic

import (
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"

	"github.com/coder/websocket"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
	admitpublic "voice-platform/backend/internal/realtime/admit_public_connection"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
)

type ConnectionObserver interface {
	PublicRealtimeConnectionOpened()
	PublicRealtimeConnectionClosed()
}

func New(origin string, observer *observestate.Observer, rate *ratelimit.Limiter, quota *admitpublic.Limiter, metrics ...ConnectionObserver) (http.Handler, error) {
	u, err := url.ParseRequestURI(origin)
	if err != nil || u == nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" || u.User != nil || u.Path != "" || u.RawQuery != "" || u.ForceQuery || u.Fragment != "" || origin != u.Scheme+"://"+u.Host || observer == nil || rate == nil || quota == nil {
		return nil, fmt.Errorf("invalid public realtime configuration")
	}
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		origins := request.Header.Values("Origin")
		if len(origins) > 1 || (len(origins) == 1 && origins[0] != origin) {
			http.Error(writer, "forbidden origin", http.StatusForbidden)
			return
		}
		if request.URL.RawQuery != "" || request.URL.ForceQuery {
			http.Error(writer, "query not allowed", http.StatusBadRequest)
			return
		}
		source := rate.SourceKey(request)
		if net.ParseIP(source) == nil {
			http.Error(writer, "invalid source", http.StatusBadRequest)
			return
		}
		if _, allowed := rate.Allow(source); !allowed {
			reject(writer)
			return
		}
		release, allowed := quota.TryAcquire(source)
		if !allowed {
			reject(writer)
			return
		}
		defer release()
		// Exact configured origin (or absent native Origin) was checked above.
		connection, err := websocket.Accept(writer, request, &websocket.AcceptOptions{InsecureSkipVerify: true})
		if err != nil {
			return
		}
		defer connection.CloseNow()
		for _, metric := range metrics {
			if metric != nil {
				metric.PublicRealtimeConnectionOpened()
				defer metric.PublicRealtimeConnectionClosed()
			}
		}
		connection.SetReadLimit(1024)
		sub := observer.Subscribe()
		defer sub.Close()
		serve(connection, sub, time.Now)
	}), nil
}

func reject(writer http.ResponseWriter) {
	writer.Header().Set("Retry-After", "1")
	http.Error(writer, "realtime connection limit", http.StatusTooManyRequests)
}
