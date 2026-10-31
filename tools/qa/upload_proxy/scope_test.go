package uploadrequest

import (
	"testing"
	"time"
)

func TestCaddyProxyKeepsOtherResponsesAndRoutesOpen(t *testing.T) {
	address := nativeProxyFixture(t)
	for _, item := range []struct {
		method, path string
		status       int
	}{
		{"POST", "/api/v1/channels/owned/attachments", 201},
		{"POST", "/api/v1/direct-messages/owned/attachments", 201},
		{"POST", "/api/other", 408},
		{"GET", "/api/v1/channels/owned/attachments", 408},
		{"POST", "/api/v1/channels/owned/attachments/extra", 408},
	} {
		t.Run(item.method+item.path, func(t *testing.T) {
			connection := proxyConnection(t, address)
			proxySend(t, connection, item.method, item.path, 1, "x")
			response, _ := proxyRead(t, connection)
			if response.StatusCode != item.status || response.Close {
				t.Fatalf("unexpected response policy: status=%d close=%v", response.StatusCode, response.Close)
			}
			proxySend(t, connection, "GET", "/api/qa-health", 0, "")
			response, _ = proxyRead(t, connection)
			if response.StatusCode != 200 {
				t.Fatalf("same connection no longer usable: %d", response.StatusCode)
			}
		})
	}
}

func TestCaddyProxyAllowsSlowProgressWithoutClosingSuccess(t *testing.T) {
	address := nativeProxyFixture(t)
	connection := proxyConnection(t, address)
	proxySend(t, connection, "POST", "/api/v1/direct-messages/owned/attachments", 6, "")
	for range 6 {
		if _, err := connection.Write([]byte("x")); err != nil {
			t.Fatal(err)
		}
		time.Sleep(25 * time.Millisecond)
	}
	response, _ := proxyRead(t, connection)
	if response.StatusCode != 201 || response.Close {
		t.Fatalf("valid slow upload status=%d close=%v", response.StatusCode, response.Close)
	}
	proxySend(t, connection, "GET", "/api/qa-health", 0, "")
	response, _ = proxyRead(t, connection)
	if response.StatusCode != 200 {
		t.Fatal("successful slow-upload connection was closed")
	}
}
