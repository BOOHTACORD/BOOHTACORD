package listtextmessagespostgres

import (
	"strings"
	"testing"
)

func TestHistoryLimitsPageBeforeJoiningAttachments(t *testing.T) {
	for _, after := range []bool{false, true} {
		query := historyQuery(after)
		limit := strings.Index(query, "LIMIT $3")
		join := strings.Index(query, "LEFT JOIN message_attachments")
		if limit < 0 || join < 0 || limit > join {
			t.Fatalf("after=%t: attachment aggregation is not limited to the requested page", after)
		}
	}
}
