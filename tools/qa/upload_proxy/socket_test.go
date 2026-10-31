package uploadrequest

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"testing"
	"time"
)

func proxyConnection(t *testing.T, address string) net.Conn {
	t.Helper()
	connection, err := net.DialTimeout("tcp", address, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = connection.Close() })
	if err := connection.SetDeadline(time.Now().Add(700 * time.Millisecond)); err != nil {
		t.Fatal(err)
	}
	return connection
}

func proxySend(t *testing.T, connection net.Conn, method, path string, length int, prefix string) {
	t.Helper()
	_, err := fmt.Fprintf(connection, "%s %s HTTP/1.1\r\nHost: %s\r\nContent-Type: multipart/form-data; boundary=qa\r\nContent-Length: %d\r\n\r\n%s", method, path, connection.RemoteAddr().String(), length, prefix)
	if err != nil {
		t.Fatal(err)
	}
}

func proxyRead(t *testing.T, connection net.Conn) (*http.Response, []byte) {
	t.Helper()
	response, err := http.ReadResponse(bufio.NewReader(connection), &http.Request{Method: http.MethodPost})
	if err != nil {
		t.Fatalf("native pinned Caddy did not deliver response before client guard: %v", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatalf("native Caddy response body incomplete: %v", err)
	}
	return response, body
}
