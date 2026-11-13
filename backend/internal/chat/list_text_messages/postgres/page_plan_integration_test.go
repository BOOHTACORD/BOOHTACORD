package listtextmessagespostgres

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

type explainDocument struct {
	Plan          map[string]any `json:"Plan"`
	ExecutionTime float64        `json:"Execution Time"`
}

func TestHistoryPlanMaterializesOnlyRequestedPage(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	seedHistoryPage(t, ctx, pool)
	if _, err := pool.Exec(ctx, `INSERT INTO messages(id,channel_id,author_id,client_message_id,body)
SELECT gen_random_uuid(),$1,$2,gen_random_uuid(),'synthetic' FROM generate_series(1,5000)`, historyChannel, historyActor); err != nil {
		t.Fatal(err)
	}
	old := explainHistory(t, ctx, pool, legacyHistoryQuery(false, false))
	current := explainHistory(t, ctx, pool, historyQuery(false))
	page, ok := findPlan(current.Plan, "CTE page")
	if !ok || page["Node Type"] != "Limit" || page["Actual Rows"].(float64) > 11 {
		t.Fatal("query did not bound the materialized page before aggregation")
	}
	t.Logf("single local SQL observation: old=%.3fms new=%.3fms; page rows=%.0f",
		old.ExecutionTime, current.ExecutionTime, page["Actual Rows"])
}

func explainHistory(t *testing.T, ctx context.Context, pool *pgxpool.Pool, query string) explainDocument {
	t.Helper()
	var data []byte
	if err := pool.QueryRow(ctx, "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "+query, historyChannel, nil, 11, false).Scan(&data); err != nil {
		t.Fatal(err)
	}
	var result []explainDocument
	if err := json.Unmarshal(data, &result); err != nil || len(result) != 1 {
		t.Fatal("invalid EXPLAIN result", err)
	}
	return result[0]
}

func findPlan(plan map[string]any, name string) (map[string]any, bool) {
	if plan["Subplan Name"] == name {
		return plan, true
	}
	children, _ := plan["Plans"].([]any)
	for _, child := range children {
		if found, ok := findPlan(child.(map[string]any), name); ok {
			return found, true
		}
	}
	return nil, false
}
