package clientupdates

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMinimumReleaseOrderCatalogAndPolicy(t *testing.T) {
	for _, tc := range []struct {
		name, value string
		valid       bool
	}{
		{"omitted", "", true}, {"minimum", `,"minimum_release_order":1`, true},
		{"target", `,"minimum_release_order":7`, true}, {"null", `,"minimum_release_order":null`, true},
		{"zero", `,"minimum_release_order":0`, false}, {"negative", `,"minimum_release_order":-1`, false},
		{"newer_than_target", `,"minimum_release_order":8`, false}, {"wrong_type", `,"minimum_release_order":"5"`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			source := strings.Replace(validCatalog, `"release_order":7`, `"release_order":7`+tc.value, 1)
			catalog, err := Parse(strings.NewReader(source), nil)
			if (err == nil) != tc.valid {
				t.Fatalf("valid=%v err=%v", tc.valid, err)
			}
			if err != nil {
				return
			}
			policy, ok := catalog.Select(Selector{Platform: "web", Distribution: "browser", Channel: "stable", Arch: "any"})
			if !ok {
				t.Fatal("policy unavailable")
			}
			response := httptest.NewRecorder()
			Handler(fixedProvider{policy: policy, ok: true}).ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/v1/client-updates?platform=web&distribution=browser&channel=stable&arch=any", nil))
			var body map[string]any
			if response.Code != 200 || json.Unmarshal(response.Body.Bytes(), &body) != nil {
				t.Fatal("invalid response")
			}
			target := body["target"].(map[string]any)
			if tc.name == "minimum" && target["minimum_release_order"] != float64(1) {
				t.Fatalf("missing minimum: %v", target)
			}
			if tc.name == "omitted" {
				if _, ok := target["minimum_release_order"]; ok {
					t.Fatal("old catalog changed")
				}
			}
		})
	}
}
