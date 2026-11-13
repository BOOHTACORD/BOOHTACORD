package listtextmessagespostgres

import (
	"context"
	"reflect"
	"strings"
	"testing"
	"time"

	"voice-platform/backend/internal/database/migrate"
	postgresfixture "voice-platform/backend/internal/testsupport/postgres"
)

const historyActor = "11111111-1111-4111-8111-111111111111"
const historyChannel = "33333333-3333-4333-8333-333333333333"

func TestHistoryPageMatchesLegacyOnDisposablePostgres(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	pool := postgresfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", postgresfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	anchor := seedHistoryPage(t, ctx, pool)
	cases := []struct {
		name         string
		cursor       any
		after, at    bool
		wantNonempty bool
	}{
		{"latest", nil, false, false, true},
		{"before", anchor, false, false, true},
		{"at", anchor, false, true, true},
		{"after", anchor, true, false, true},
		{"tie before", "77777777-7777-4777-8777-777777777772", false, false, true},
		{"tie after", "77777777-7777-4777-8777-777777777771", true, false, true},
		{"foreign cursor", "77777777-7777-4777-8777-777777777773", false, false, false},
		{"missing cursor", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", false, false, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			args := []any{historyChannel, tc.cursor, 11, tc.at}
			old := historyRows(t, ctx, pool, legacyHistoryQuery(tc.after, false), args...)
			current := historyRows(t, ctx, pool, historyQuery(tc.after), args...)
			if (len(old) > 0) != tc.wantNonempty || !reflect.DeepEqual(old, current) {
				t.Fatalf("history differs: legacy=%d current=%d", len(old), len(current))
			}
			if tc.name == "latest" {
				attachments, ok := old[0][11].(string)
				if !ok || !strings.Contains(attachments, "first.txt") || !strings.Contains(attachments, "second.txt") || strings.Contains(attachments, "hidden.txt") || strings.Index(attachments, "first.txt") > strings.Index(attachments, "second.txt") {
					t.Fatal("fixture did not verify ordered visible attachments")
				}
				deleted := false
				for _, row := range old {
					if row[9] == true {
						deleted = row[4] == "" && row[11] == "[]"
					}
				}
				if !deleted {
					t.Fatal("fixture did not verify deleted-message redaction")
				}
			}
		})
	}
	if _, err := pool.Exec(ctx, `UPDATE channels SET archived_at=now(), readonly_archive=true WHERE id=$1`, historyChannel); err != nil {
		t.Fatal(err)
	}
	for _, blocked := range []bool{false, true} {
		if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at=CASE WHEN $2 THEN now() ELSE NULL END WHERE id=$1`, historyActor, blocked); err != nil {
			t.Fatal(err)
		}
		for _, after := range []bool{false, true} {
			args := []any{historyChannel, anchor, 11, false, historyActor}
			old := historyRows(t, ctx, pool, legacyHistoryQuery(after, true), args...)
			current := historyRows(t, ctx, pool, archiveHistoryQuery(after), args...)
			if (len(old) == 0) != blocked || !reflect.DeepEqual(old, current) {
				t.Fatalf("archive differs: blocked=%t after=%t legacy=%d current=%d", blocked, after, len(old), len(current))
			}
		}
	}
}
