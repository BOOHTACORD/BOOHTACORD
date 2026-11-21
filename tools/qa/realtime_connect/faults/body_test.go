package main

import (
	"context"
	"io"
	"net"
	"testing"
	"time"
)

func TestClientCloseReleasesDelayedActualBytes(t *testing.T) {
	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()
	record := &sample{start: time.Now()}
	body := &delayedBody{ReadWriteCloser: client, ctx: context.Background(), sample: record}
	result := make(chan string, 1)
	go func() { bytes := make([]byte, 9); n, _ := body.Read(bytes); result <- string(bytes[:n]) }()
	go func() {
		bytes := make([]byte, 2)
		_, _ = io.ReadFull(server, bytes)
		_, _ = server.Write([]byte("unchanged"))
	}()
	_, _ = body.Write([]byte{0x88, 0x80}) // Actual client WebSocket close opcode.
	select {
	case bytes := <-result:
		if bytes != "unchanged" {
			t.Fatal("proxy changed actual bytes")
		}
	case <-time.After(time.Second):
		t.Fatal("fault gate held backend close behind delayed ready")
	}
}
