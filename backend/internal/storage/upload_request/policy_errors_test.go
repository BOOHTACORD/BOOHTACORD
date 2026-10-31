package uploadrequest

import (
	"context"
	"errors"
	"io"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func TestPolicyTimeoutIsMarkedBeforeNativeReadCancelsParent(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader, source := io.Pipe()
	defer source.Close()
	request := httptest.NewRequest("POST", "/", nil).WithContext(ctx)
	request.Body = reader
	contexts, observed := make(chan context.Context, 1), make(chan bool, 1)
	writer := &parentCancellingWriter{deadlineRecorder: newDeadlineRecorder()}
	writer.onPast = func() {
		observed <- TimedOut(<-contexts)
		cancel()
		_ = reader.CloseWithError(os.ErrDeadlineExceeded)
	}
	bounded, cleanup, err := WithLimits(writer, request, time.Second, 10*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	contexts <- bounded.Context()
	_, err = bounded.Body.Read(make([]byte, 1))
	if !<-observed || !TimedOut(bounded.Context()) || !errors.Is(context.Cause(bounded.Context()), ErrReadTimeout) || !errors.Is(err, ErrReadTimeout) {
		t.Fatalf("policy actor did not classify before native cancellation: %v", err)
	}
}

func TestUnrelatedReadFailuresRemainSeparateFromPolicyTimeout(t *testing.T) {
	for _, failure := range []error{os.ErrDeadlineExceeded, unrelatedTimeout{}, io.ErrUnexpectedEOF} {
		request := httptest.NewRequest("POST", "/", nil)
		ctx, cancel := context.WithCancel(request.Context())
		request = request.WithContext(ctx)
		request.Body = io.NopCloser(failedRead{err: failure, before: cancel})
		bounded, cleanup, err := WithLimits(newDeadlineRecorder(), request, time.Second, time.Second)
		if err != nil {
			t.Fatal(err)
		}
		_, _ = bounded.Body.Read(make([]byte, 1))
		timeout := TimedOut(bounded.Context())
		cleanup()
		cancel()
		if timeout {
			t.Fatalf("unowned failure became policy timeout: %v", failure)
		}
	}
}

func TestEarlierIdleCallbackCannotExpireNewProgressWindow(t *testing.T) {
	request := httptest.NewRequest("POST", "/", strings.NewReader("progress"))
	bounded, cleanup, err := WithLimits(newDeadlineRecorder(), request, time.Second, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	if _, err := bounded.Body.Read(make([]byte, 1)); err != nil {
		t.Fatal(err)
	}
	// AfterFunc.Reset may leave the previous callback already queued.
	bounded.Body.(*boundedBody).interrupt(ErrReadTimeout)
	if TimedOut(bounded.Context()) {
		t.Fatal("stale idle callback expired fresh progress")
	}
	if _, err := bounded.Body.Read(make([]byte, 1)); err != nil {
		t.Fatal(err)
	}
}

type parentCancellingWriter struct {
	*deadlineRecorder
	onPast func()
}

func (writer *parentCancellingWriter) SetReadDeadline(at time.Time) error {
	if !at.IsZero() && !at.After(time.Now()) {
		writer.onPast()
	}
	return nil
}

type failedRead struct {
	err    error
	before func()
}

func (reader failedRead) Read([]byte) (int, error) {
	if reader.before != nil {
		reader.before()
	}
	return 0, reader.err
}

type unrelatedTimeout struct{}

func (unrelatedTimeout) Error() string { return "unrelated upstream timeout" }
func (unrelatedTimeout) Timeout() bool { return true }
