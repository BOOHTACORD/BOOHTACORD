package uploadrequest

import (
	"context"
	"errors"
	"io"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestIdleDeadlineClosesBlockedBodyAndCancelsRequest(t *testing.T) {
	request := httptest.NewRequest("POST", "/", nil)
	request.Body = &blockingReader{closed: make(chan struct{})}
	bounded, cleanup, err := WithLimits(newDeadlineRecorder(), request, time.Second, 10*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	defer bounded.Body.Close()
	read := make(chan error, 1)
	go func() { _, err := bounded.Body.Read(make([]byte, 1)); read <- err }()
	select {
	case <-read:
	case <-time.After(time.Second):
		t.Fatal("idle request body remained blocked")
	}
	if !errors.Is(context.Cause(bounded.Context()), ErrReadTimeout) {
		t.Fatalf("context cause = %v", context.Cause(bounded.Context()))
	}
}

func TestProgressResetsIdleDeadline(t *testing.T) {
	request := httptest.NewRequest("POST", "/", io.NopCloser(strings.NewReader("payload")))
	bounded, cleanup, err := WithLimits(newDeadlineRecorder(), request, time.Second, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	body, err := io.ReadAll(bounded.Body)
	if err != nil || string(body) != "payload" {
		t.Fatalf("body = %q, error = %v", body, err)
	}
	if context.Cause(bounded.Context()) != nil {
		t.Fatalf("context cause = %v", context.Cause(bounded.Context()))
	}
}

type blockingReader struct{ closed chan struct{} }

func (reader *blockingReader) Read([]byte) (int, error) {
	<-reader.closed
	return 0, errors.New("closed")
}
func (reader *blockingReader) Close() error {
	select {
	case <-reader.closed:
	default:
		close(reader.closed)
	}
	return nil
}
