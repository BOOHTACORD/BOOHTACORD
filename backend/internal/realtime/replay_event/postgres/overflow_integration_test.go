package replayeventpostgres

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestPostgresReplayLimitBoundary(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	db := postgresfixture.New(t, ctx, "TEST_DATABASE_URL", postgresfixture.LoopbackOrLocalhost)
	migration, err := os.ReadFile("../../../database/migrate/migrations/0036_create_realtime_events.sql")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, string(migration)); err != nil {
		t.Fatal(err)
	}
	applyTraceMigration(t, ctx, db)
	repository, epoch, account := New(db), uuid.NewString(), uuid.NewString()
	appendEvent := func(revision int) string {
		t.Helper()
		event := eventhub.Event{
			EventID: uuid.NewString(), Kind: "channel.updated", OccurredAt: time.Now().UTC(),
			Payload: map[string]any{"revision": revision},
		}
		if err := repository.Append(ctx, event, nil, epoch); err != nil {
			t.Fatalf("append revision %d: %v", revision, err)
		}
		return event.EventID
	}
	cursor := appendEvent(1)
	var first, last string
	for i := 0; i < ReplayLimit; i++ {
		id := appendEvent(i + 2)
		if i == 0 {
			first = id
		}
		last = id
	}
	events, err := repository.Replay(ctx, account, cursor, epoch, ReplayLimit)
	if err != nil || len(events) != ReplayLimit {
		t.Fatalf("at limit: count=%d error=%v", len(events), err)
	}
	if events[0].EventID != first || events[len(events)-1].EventID != last {
		t.Fatal("events at limit were not returned in append order")
	}
	appendEvent(ReplayLimit + 2)
	events, err = repository.Replay(ctx, account, cursor, epoch, ReplayLimit)
	if !errors.Is(err, ErrReplayOverflow) || len(events) != 0 {
		t.Fatalf("above limit: count=%d error=%v", len(events), err)
	}
}
