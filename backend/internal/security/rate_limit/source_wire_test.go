package ratelimit

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

func TestSourceKeyLiteralHTTP1RetainsOrderedFields(t *testing.T) {
	trusted, err := parseTrustedProxies([]string{"127.0.0.1/32", "10.0.0.0/8"})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprintf(writer, "%s|%d", sourceKey(request, trusted), len(request.Header.Values("X-Forwarded-For")))
	}))
	defer server.Close()
	cases := []struct{ name, headers, want string }{
		{"separate", "X-Forwarded-For: 203.0.113.9\r\nX-Forwarded-For: 192.0.2.9,10.0.0.4\r\n", "192.0.2.9|2"},
		{"combined", "X-Forwarded-For: 203.0.113.9,192.0.2.9,10.0.0.4\r\n", "192.0.2.9|1"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			connection, err := net.DialTimeout("tcp", strings.TrimPrefix(server.URL, "http://"), time.Second)
			if err != nil {
				t.Fatal(err)
			}
			defer connection.Close()
			if err := connection.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
				t.Fatal(err)
			}
			_, err = fmt.Fprintf(connection, "GET / HTTP/1.1\r\nHost: qa.invalid\r\nConnection: close\r\n%s\r\n", tc.headers)
			if err != nil {
				t.Fatal(err)
			}
			response, err := http.ReadResponse(bufio.NewReader(connection), &http.Request{Method: http.MethodGet})
			if err != nil {
				t.Fatal(err)
			}
			defer response.Body.Close()
			body, err := io.ReadAll(response.Body)
			if err != nil || response.StatusCode != http.StatusOK || string(body) != tc.want {
				t.Fatalf("literal HTTP1 source/count = %q, status %d, error %v; want %q", body, response.StatusCode, err, tc.want)
			}
		})
	}
}
