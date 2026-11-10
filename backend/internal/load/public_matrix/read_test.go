package publicmatrix

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestPublicReaderRejectsPrivateEventAfterSnapshot(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		for _, event := range [][]byte{
			testFrame("connection.ready", `{}`),
			testFrame("maintenance.snapshot", `{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}`),
			testFrame("message.created", `{"body":"private-fixture"}`),
		} {
			if conn.Write(ctx, websocket.MessageText, event) != nil {
				return
			}
		}
	}))
	defer server.Close()
	conn, err := Open(ctx, server.Client(), server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	var kinds []string
	err = Read(ctx, conn, time.Now(), func(kind string, _ time.Duration) { kinds = append(kinds, kind) })
	if err == nil || len(kinds) != 2 || kinds[0] != "ready" || kinds[1] != "maintenance" {
		t.Fatal("public privacy violation not detected")
	}
}
