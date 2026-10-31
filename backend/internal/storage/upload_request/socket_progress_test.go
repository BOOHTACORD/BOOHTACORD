package uploadrequest

import (
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"
)

func TestSocketSlowProgressRemainsAllowed(t *testing.T) {
	connection := socketForHandler(t, http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		bounded, cleanup, err := WithLimits(writer, request, 500*time.Millisecond, 90*time.Millisecond)
		if err != nil {
			http.Error(writer, "INTERNAL", 500)
			return
		}
		defer cleanup()
		defer bounded.Body.Close()
		_, err = io.Copy(io.Discard, bounded.Body)
		if err != nil {
			http.Error(writer, "READ_FAILED", 500)
			return
		}
		writer.WriteHeader(http.StatusCreated)
	}))
	_, _ = fmt.Fprint(connection, "POST /upload HTTP/1.1\r\nHost: qa.local\r\nContent-Length: 6\r\n\r\n")
	for range 6 {
		if _, err := connection.Write([]byte("x")); err != nil {
			t.Fatal(err)
		}
		time.Sleep(25 * time.Millisecond)
	}
	if status := socketStatus(t, connection); status != http.StatusCreated {
		t.Fatalf("slow progress status=%d", status)
	}
}

func TestSocketProgressNeverExtendsAbsoluteDeadline(t *testing.T) {
	connection, timedOut := stalledSocket(t, 120*time.Millisecond, 70*time.Millisecond, "x")
	stop, done := make(chan struct{}), make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(20 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				if _, err := connection.Write([]byte("x")); err != nil {
					return
				}
			}
		}
	}()
	defer func() { close(stop); <-done }()
	if status := socketStatus(t, connection); status != http.StatusRequestTimeout || !<-timedOut {
		t.Fatalf("absolute progress status=%d", status)
	}
}
