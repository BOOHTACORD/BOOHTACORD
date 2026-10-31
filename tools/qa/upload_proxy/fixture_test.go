package uploadrequest

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func nativeProxyFixture(t *testing.T) string {
	t.Helper()
	binary := pinnedProxyBinary(t)
	backend := httptest.NewServer(http.HandlerFunc(proxyFixtureBackend))
	t.Cleanup(backend.Close)
	address := proxyListenAddress(t)
	input, err := os.ReadFile(os.Getenv("BOOHTACORD_QA_CADDYFILE"))
	if err != nil {
		t.Fatal(err)
	}
	config := strings.ReplaceAll(string(input), "{$PUBLIC_HOST:localhost}", "http://"+address)
	config = strings.ReplaceAll(config, "api:8080", strings.TrimPrefix(backend.URL, "http://"))
	config = "{\n admin off\n auto_https off\n}\n" + config
	directory := t.TempDir()
	name := filepath.Join(directory, "Caddyfile")
	if err := os.WriteFile(name, []byte(config), 0600); err != nil {
		t.Fatal(err)
	}
	log, err := os.Create(filepath.Join(directory, "native-caddy.log"))
	if err != nil {
		t.Fatal(err)
	}
	command := exec.Command(binary, "run", "--config", name, "--adapter", "caddyfile")
	command.Env = append(os.Environ(), "XDG_CONFIG_HOME="+filepath.Join(directory, "config"), "XDG_DATA_HOME="+filepath.Join(directory, "data"), "XDG_CACHE_HOME="+filepath.Join(directory, "cache"))
	command.Stdout, command.Stderr = log, log
	if err := command.Start(); err != nil {
		log.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = command.Process.Kill(); _ = command.Wait(); _ = log.Close() })
	client := &http.Client{Timeout: 100 * time.Millisecond, Transport: &http.Transport{Proxy: nil, DisableKeepAlives: true}}
	defer client.CloseIdleConnections()
	for until := time.Now().Add(3 * time.Second); time.Now().Before(until); time.Sleep(10 * time.Millisecond) {
		response, err := client.Get("http://" + address + "/api/qa-health")
		if err == nil {
			response.Body.Close()
			if response.StatusCode == 200 {
				return address
			}
		}
	}
	output, _ := os.ReadFile(filepath.Join(directory, "native-caddy.log"))
	t.Fatal(fmt.Sprintf("owned Caddy did not become ready: %.2000s", output))
	return ""
}
