package clientupdates

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestSourceCatalogLoadsForNativeSelectors(t *testing.T) {
	path := filepath.Join("..", "..", "..", "..", "deploy", "client-updates", "catalog.json")
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	hosts := []string{"v.bootybay.ru", "github.com"}
	document, err := Parse(bytes.NewReader(before), hosts)
	if err != nil {
		t.Fatal("source catalog does not satisfy runtime validation:", err)
	}
	store := NewStore(path, hosts)
	if err := store.Reload(); err != nil {
		t.Fatal("source catalog could not initialize a runtime snapshot:", err)
	}
	for _, selector := range []Selector{
		{Platform: "windows", Distribution: "direct", Channel: "stable", Arch: "x64"},
		{Platform: "android", Distribution: "direct", Channel: "stable", Arch: "arm64"},
	} {
		t.Run(selector.Platform, func(t *testing.T) {
			matches := 0
			for _, entry := range document.Entries {
				if entry.Selector == selector {
					matches++
				}
			}
			if matches != 1 {
				t.Fatal("source catalog must contain the exact native selector")
			}
			recorder := httptest.NewRecorder()
			query := "/api/v1/client-updates?platform=" + selector.Platform + "&distribution=direct&channel=stable&arch=" + selector.Arch
			Handler(store).ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, query, nil))
			if recorder.Code != http.StatusOK || recorder.Header().Get("Cache-Control") != "no-store" {
				t.Fatalf("source policy status/cache contract differs: %d", recorder.Code)
			}
			var observed Policy
			if err := json.Unmarshal(recorder.Body.Bytes(), &observed); err != nil {
				t.Fatal(err)
			}
			expected, _ := document.Select(selector)
			if !reflect.DeepEqual(observed, expected) {
				t.Fatal("runtime policy differs from the exact source entry")
			}
		})
	}
	if err := store.Reload(); err != nil {
		t.Fatal("identical source reload failed:", err)
	}
	after, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(before, after) {
		t.Fatal("runtime validation changed source catalog bytes")
	}
}
