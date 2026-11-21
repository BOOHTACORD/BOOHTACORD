package main

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestControlRequiresTokenAndFiniteMode(t *testing.T) {
	s := newState("owned-nonce")
	for _, token := range []string{"", "Bearer wrong"} {
		req := httptest.NewRequest("POST", "/qa-r2/control", strings.NewReader(`{"mode":"upgrade-stall"}`))
		req.Header.Set("Authorization", token)
		w := httptest.NewRecorder()
		s.control(w, req)
		if w.Code != 403 {
			t.Fatal("unauthenticated control accepted")
		}
	}
	req := httptest.NewRequest("POST", "/qa-r2/control", strings.NewReader(`{"mode":"arbitrary"}`))
	req.Header.Set("Authorization", "Bearer owned-nonce")
	w := httptest.NewRecorder()
	s.control(w, req)
	if w.Code != 400 {
		t.Fatal("unbounded mode accepted")
	}
}

func TestModeIsExactPathAndSingleUse(t *testing.T) {
	s := newState("owned-nonce")
	s.arm("upgrade-stall")
	if s.take("/api/v1/auth/session") != "" {
		t.Fatal("wrong path consumed fault")
	}
	if s.take("/api/v1/realtime") != "upgrade-stall" {
		t.Fatal("fault not consumed")
	}
	if s.take("/api/v1/realtime") != "" {
		t.Fatal("fault reused")
	}
	s.arm("public-upgrade-stall")
	if s.take("/api/v1/realtime") != "" {
		t.Fatal("public fault consumed by authenticated socket")
	}
	if s.take("/api/v1/public/realtime") != "public-upgrade-stall" {
		t.Fatal("public fault not consumed")
	}
}

func TestCancelledWaitDoesNotHoldRequest(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	started := time.Now()
	if wait(ctx, time.Minute) {
		t.Fatal("cancelled wait completed normally")
	}
	if time.Since(started) > time.Second {
		t.Fatal("request cancellation was not bounded")
	}
}
