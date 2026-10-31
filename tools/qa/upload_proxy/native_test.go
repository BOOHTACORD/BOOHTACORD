package uploadrequest

import (
	"crypto/sha256"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"strings"
	"testing"
)

func pinnedProxyBinary(t *testing.T) string {
	t.Helper()
	binary, want := os.Getenv("BOOHTACORD_QA_CADDY_BIN"), os.Getenv("BOOHTACORD_QA_CADDY_SHA")
	if binary == "" || len(want) != 64 {
		t.Fatal("exact native Caddy binary and SHA are mandatory; no skip/fallback")
	}
	file, err := os.Open(binary)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		t.Fatal(err)
	}
	if fmt.Sprintf("%x", hash.Sum(nil)) != want {
		t.Fatal("native Caddy SHA differs")
	}
	version, err := exec.Command(binary, "version").Output()
	if err != nil || !strings.HasPrefix(string(version), "v2.10.0 ") {
		t.Fatalf("native pinned Caddy2.10.0 required: %v", err)
	}
	t.Logf("native Caddy2.10.0 binary SHA256=%s", want)
	return binary
}

func proxyListenAddress(t *testing.T) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	if err := listener.Close(); err != nil {
		t.Fatal(err)
	}
	return address
}
