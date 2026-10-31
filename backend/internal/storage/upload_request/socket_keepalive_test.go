package uploadrequest

import (
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"
)

func TestSocketUploadDeadlineDoesNotLeakIntoNextKeepAliveRequest(t *testing.T) {
	connection := socketForHandler(t, http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		status := http.StatusOK
		if request.URL.Path == "/upload" {
			bounded, cleanup, err := WithLimits(writer, request, 400*time.Millisecond, 50*time.Millisecond)
			if err != nil {
				http.Error(writer, "INTERNAL", 500)
				return
			}
			request = bounded
			defer cleanup()
			defer request.Body.Close()
			status = http.StatusCreated
		}
		if _, err := io.Copy(io.Discard, request.Body); err != nil {
			http.Error(writer, "LEAKED_DEADLINE", 500)
			return
		}
		writer.WriteHeader(status)
	}))
	_, _ = fmt.Fprint(connection, "POST /upload HTTP/1.1\r\nHost: qa.local\r\nContent-Length: 1\r\n\r\nx")
	if status := socketStatus(t, connection); status != http.StatusCreated {
		t.Fatalf("upload status=%d", status)
	}
	_, _ = fmt.Fprint(connection, "POST /non-upload HTTP/1.1\r\nHost: qa.local\r\nContent-Length: 1\r\n\r\n")
	// The previous handler context has now been cancelled by net/http. Its watcher
	// and both upload timers must not touch this live next request's connection.
	time.Sleep(150 * time.Millisecond)
	if _, err := connection.Write([]byte("y")); err != nil {
		t.Fatal(err)
	}
	if status := socketStatus(t, connection); status != http.StatusOK {
		t.Fatalf("reused non-upload status=%d", status)
	}
}
