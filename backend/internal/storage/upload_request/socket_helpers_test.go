package uploadrequest

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func stalledSocket(t *testing.T, maximum, idle time.Duration, prefix string) (net.Conn, <-chan bool) {
	t.Helper()
	timedOut := make(chan bool, 1)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		request, cleanup, err := WithLimits(writer, request, maximum, idle)
		if err != nil {
			http.Error(writer, "INTERNAL", http.StatusInternalServerError)
			return
		}
		defer cleanup()
		defer request.Body.Close()
		_, readErr := io.Copy(io.Discard, request.Body)
		timeout := TimedOut(request.Context())
		if !timeout && readErr != nil {
			t.Logf("unexpected non-policy read error: %T %v", readErr, readErr)
		}
		timedOut <- timeout
		if timeout {
			http.Error(writer, "UPLOAD_TIMEOUT", http.StatusRequestTimeout)
			return
		}
		writer.WriteHeader(http.StatusCreated)
	}))
	t.Cleanup(server.Close)
	connection, err := net.DialTimeout("tcp", strings.TrimPrefix(server.URL, "http://"), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = connection.Close() })
	if err := connection.SetDeadline(time.Now().Add(600 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	_, err = fmt.Fprintf(connection, "POST /upload HTTP/1.1\r\nHost: qa.local\r\nContent-Type: multipart/form-data; boundary=qa\r\nContent-Length: 1000000\r\nConnection: close\r\n\r\n%s", prefix)
	if err != nil {
		t.Fatal(err)
	}
	return connection, timedOut
}

func socketForHandler(t *testing.T, handler http.Handler) net.Conn {
	t.Helper()
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	connection, err := net.DialTimeout("tcp", strings.TrimPrefix(server.URL, "http://"), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = connection.Close() })
	if err := connection.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	return connection
}

func socketStatus(t *testing.T, connection net.Conn) int {
	t.Helper()
	response, err := http.ReadResponse(bufio.NewReader(connection), &http.Request{Method: http.MethodPost})
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if _, err := io.Copy(io.Discard, response.Body); err != nil {
		t.Fatal(err)
	}
	return response.StatusCode
}
