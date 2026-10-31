package uploadrequest

import (
	"bufio"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestSocketDeadlineUnblocksRealHTTP1Body(t *testing.T) {
	for _, policy := range []struct {
		name          string
		maximum, idle time.Duration
	}{
		{"idle", time.Second, 40 * time.Millisecond},
		{"absolute", 40 * time.Millisecond, time.Second},
	} {
		for _, partial := range []bool{false, true} {
			name := policy.name + "/zero-body"
			prefix := ""
			if partial {
				name = policy.name + "/partial-multipart"
				prefix = "--qa\r\nContent-Disposition: form-data; name=\"file\"; filename=\"qa.bin\"\r\n\r\n" + strings.Repeat("x", 8192)
			}
			t.Run(name, func(t *testing.T) {
				connection, timedOut := stalledSocket(t, policy.maximum, policy.idle, prefix)
				response, err := http.ReadResponse(bufio.NewReader(connection), &http.Request{Method: http.MethodPost})
				if err != nil {
					t.Fatalf("real HTTP1 read remained blocked past the40ms policy: %v", err)
				}
				defer response.Body.Close()
				body, err := io.ReadAll(response.Body)
				if err != nil || response.StatusCode != http.StatusRequestTimeout || !strings.Contains(string(body), "UPLOAD_TIMEOUT") || !<-timedOut {
					t.Fatalf("status=%d, timeout code/cause missing, read error=%v", response.StatusCode, err)
				}
			})
		}
	}
}
