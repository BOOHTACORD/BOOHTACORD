package screenviewerpresence

import (
	"context"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"testing"
)

func TestPresenceRecordsOnlyActualAuthorizedTransitions(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(context.Background())
	store := &testStore{watching: map[string]bool{}}
	service, err := New(testAuthority{channel: "channel", ownerAccount: "owner", viewerAccount: "viewer"}, &testPublication{track: "TR_private"}, store, nil)
	if err != nil {
		t.Fatal(err)
	}
	const viewer = "11111111-1111-4111-8111-111111111111"
	const owner = "22222222-2222-4222-8222-222222222222"
	ctx, span := provider.Tracer("test").Start(context.Background(), "request")
	for i := 0; i < 3; i++ {
		if err := service.Watch(ctx, Principal{AccountID: "viewer"}, viewer, owner, "TR_private"); err != nil {
			t.Fatal(err)
		}
	}
	if err := service.StopWatching(ctx, Principal{AccountID: "viewer"}, viewer, owner, "TR_private"); err != nil {
		t.Fatal(err)
	}
	if err := service.ClearOwner(ctx, Principal{AccountID: "owner"}, owner, "TR_private"); err != nil {
		t.Fatal(err)
	}
	span.End()
	events := recorder.Ended()[0].Events()
	want := []string{"app.screen.viewer.started", "app.screen.viewer.stopped", "app.screen.audience.cleared"}
	if len(events) != len(want) {
		t.Fatalf("events=%v", events)
	}
	for i, event := range events {
		if event.Name != want[i] || len(event.Attributes) != 0 {
			t.Fatalf("unexpected event %v", event)
		}
	}
}

func TestPresenceRejectionDoesNotRecordSuccessEvent(t *testing.T) {
	recorder := tracetest.NewSpanRecorder()
	provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
	defer provider.Shutdown(context.Background())
	service, _ := New(testAuthority{err: ErrDenied}, &testPublication{}, &testStore{watching: map[string]bool{}}, nil)
	ctx, span := provider.Tracer("test").Start(context.Background(), "rejected")
	if err := service.Watch(ctx, Principal{}, "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222", "TR_private"); err == nil {
		t.Fatal("expected rejection")
	}
	span.End()
	if len(recorder.Ended()[0].Events()) != 0 {
		t.Fatal("rejected request looked like a successful view")
	}
}
