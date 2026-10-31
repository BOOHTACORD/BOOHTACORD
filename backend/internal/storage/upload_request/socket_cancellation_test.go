package uploadrequest

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"
)

func TestSocketParentCancellationUnblocksReadWithoutPolicyTimeout(t *testing.T) {
	cancelRequest := make(chan context.CancelFunc, 1)
	connection := socketForHandler(t, http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		ctx, cancel := context.WithCancel(request.Context())
		defer cancel()
		bounded, cleanup, err := WithLimits(writer, request.WithContext(ctx), time.Second, time.Second)
		if err != nil {
			http.Error(writer, "INTERNAL", 500)
			return
		}
		defer cleanup()
		defer bounded.Body.Close()
		cancelRequest <- cancel
		_, _ = io.Copy(io.Discard, bounded.Body)
		if !errors.Is(context.Cause(bounded.Context()), context.Canceled) || TimedOut(bounded.Context()) {
			http.Error(writer, "WRONG_CAUSE", 500)
			return
		}
		writer.Header().Set("Connection", "close")
		writer.WriteHeader(499)
	}))
	_, _ = fmt.Fprint(connection, "POST /upload HTTP/1.1\r\nHost: qa.local\r\nContent-Length: 1000000\r\n\r\n")
	select {
	case cancel := <-cancelRequest:
		cancel()
	case <-time.After(time.Second):
		t.Fatal("request did not enter handler")
	}
	if status := socketStatus(t, connection); status != 499 {
		t.Fatalf("cancellation status=%d", status)
	}
}
