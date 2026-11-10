package connectpublic

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestOriginBoundaryRejectsAmbiguousHeaders(t *testing.T) {
	server, _, _ := setup(t, 100)
	for name, origins := range map[string][]string{
		"foreign":   {"https://evil.test"},
		"null":      {"null"},
		"scheme":    {"http://voice.example.test"},
		"port":      {"https://voice.example.test:444"},
		"comma":     {"https://voice.example.test, https://evil.test"},
		"duplicate": {"https://voice.example.test", "https://evil.test"},
		"empty":     {""},
	} {
		t.Run(name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			header := http.Header{"Origin": origins}
			conn, response, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{HTTPHeader: header})
			if conn != nil {
				conn.CloseNow()
			}
			if err == nil || response == nil || response.StatusCode != http.StatusForbidden {
				t.Fatalf("ambiguous origin accepted or wrong status: response=%v error=%v", response, err)
			}
		})
	}
}
