package connectpublic

import (
	"context"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestClientCommandsCloseThePublicSocket(t *testing.T) {
	server, _, _ := setup(t, 100)
	socket, _, err := dial(t, server, "", "")
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	read(t, socket)
	read(t, socket)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := socket.Write(ctx, websocket.MessageText, []byte(`{"command":"subscribe"}`)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := socket.Read(ctx); err == nil {
		t.Fatal("public socket accepted a client command")
	}
}
