package tracehttp

import (
	"context"
	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHTTPSpanDistinguishesRequestCancellationAndDeadline(t *testing.T) {
	for _, deadline := range []bool{false, true} {
		t.Run(map[bool]string{false: "cancelled", true: "deadline"}[deadline], func(t *testing.T) {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
			defer provider.Shutdown(t.Context())
			var ctx context.Context
			var cancel context.CancelFunc
			if deadline {
				ctx, cancel = context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
			} else {
				ctx, cancel = context.WithCancel(context.Background())
				cancel()
			}
			defer cancel()
			mux := http.NewServeMux()
			mux.HandleFunc("PUT /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) })
			Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("PUT", "/api/v1/voice/leases/private/screen-viewers/owner", nil).WithContext(ctx))
			got := recorder.Ended()[0]
			if deadline {
				if got.Status().Code != codes.Error || got.Status().Description != "request_deadline" {
					t.Fatal("deadline lost")
				}
			} else {
				if got.Status().Code == codes.Error || len(got.Events()) != 1 || got.Events()[0].Name != "app.http.cancelled" {
					t.Fatal("cancellation confused with failure")
				}
			}
		})
	}
}
