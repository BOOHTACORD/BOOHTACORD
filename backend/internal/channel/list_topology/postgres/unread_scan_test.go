package listtopologypostgres

import (
	"strings"
	"testing"
)

func TestUnreadCountsShareOneMessageScan(t *testing.T) {
	if scans := strings.Count(selectTopology, "FROM messages AS message"); scans != 2 {
		t.Fatalf("want one scan for counts and one for the first unread message; got %d", scans)
	}
	if !strings.Contains(selectTopology, "COUNT(*) FILTER (WHERE $1::uuid = ANY(message.mention_user_ids))") {
		t.Fatal("mention count must be computed over the same unread messages")
	}
}
