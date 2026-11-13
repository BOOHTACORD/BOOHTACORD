package listtopologypostgres

import (
	"context"
	"reflect"
	"testing"
	"time"

	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestTopologyUnreadMatchesLegacyOnPostgres(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	seedTopologyUnread(t, ctx, pool)
	for _, actor := range []string{topologyActor, topologyAuthor} {
		old := topologyRows(t, ctx, pool, legacySelectTopology, actor)
		current := topologyRows(t, ctx, pool, selectTopology, actor)
		if len(old) != 3 || !reflect.DeepEqual(old, current) {
			t.Fatalf("topology differs for fixture actor: legacy=%d current=%d", len(old), len(current))
		}
		if actor == topologyActor && (old[0][9] != int64(3) || old[0][10] != int64(2) || old[0][11] != topologyFirstUnread) {
			t.Fatalf("fixture did not exercise unread, mentions and first unread: %#v", old[0][9:])
		}
	}
}
