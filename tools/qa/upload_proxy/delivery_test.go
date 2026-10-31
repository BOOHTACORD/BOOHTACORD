package uploadrequest

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"testing"
)

func TestCaddyProxyDeliversEarlyUpload408(t *testing.T) {
	address := nativeProxyFixture(t)
	for _, kind := range []string{"channels", "direct-messages"} {
		for _, partial := range []bool{false, true} {
			t.Run(fmt.Sprintf("%s/partial=%t", kind, partial), func(t *testing.T) {
				connection := proxyConnection(t, address)
				prefix := ""
				if partial {
					prefix = "--qa\r\nContent-Disposition: form-data; name=\"file\"; filename=\"owned.bin\"\r\n\r\n" + strings.Repeat("x", 8192)
				}
				proxySend(t, connection, "POST", "/api/v1/"+kind+"/owned/attachments", 1000000, prefix)
				response, body := proxyRead(t, connection)
				var payload struct{ Error struct{ Code string } }
				if err := json.Unmarshal(body, &payload); err != nil || response.StatusCode != 408 || payload.Error.Code != "UPLOAD_TIMEOUT" || !response.Close {
					t.Fatalf("status=%d code=%s close=%v error=%v", response.StatusCode, payload.Error.Code, response.Close, err)
				}
				// Keep the client open: the timeout response must close the peer itself.
				if count, err := connection.Read(make([]byte, 1)); count != 0 || !errors.Is(err, io.EOF) {
					t.Fatalf("proxy kept timed-out connection alive: count=%d error=%v", count, err)
				}
			})
		}
	}
}
