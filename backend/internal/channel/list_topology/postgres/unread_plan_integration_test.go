package listtopologypostgres

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestTopologyUnreadPlanObservation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	seedTopologyUnread(t, ctx, pool)
	if _, err := pool.Exec(ctx, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body)
SELECT gen_random_uuid(),'33333333-3333-4333-8333-333333333331',$1,gen_random_uuid(),'synthetic' FROM generate_series(1,5000)`, topologyAuthor); err != nil {
		t.Fatal(err)
	}
	old := explainTopology(t, ctx, pool, legacySelectTopology)
	current := explainTopology(t, ctx, pool, selectTopology)
	t.Logf("single local SQL observation: old=%.3fms new=%.3fms", old, current)
}

func explainTopology(t *testing.T, ctx context.Context, pool *pgxpool.Pool, query string) float64 {
	t.Helper()
	var raw []byte
	if err := pool.QueryRow(ctx, "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "+query, topologyActor).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	var plan []struct {
		ExecutionTime float64 `json:"Execution Time"`
	}
	if err := json.Unmarshal(raw, &plan); err != nil || len(plan) != 1 {
		t.Fatal("invalid EXPLAIN result", err)
	}
	return plan[0].ExecutionTime
}
