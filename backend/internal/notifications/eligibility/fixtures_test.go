package eligibility

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestSharedPolicyFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	raw, err := os.ReadFile(filepath.Join(filepath.Dir(file), "../../../../contracts/notification-policy-v1.fixtures.json"))
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Version int `json:"version"`
		Cases   []struct {
			Name     string `json:"name"`
			Input    Input  `json:"input"`
			Expected Result `json:"expected"`
		} `json:"cases"`
	}
	if err = json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	if fixture.Version != 1 || len(fixture.Cases) < 25 {
		t.Fatal("incomplete fixture contract")
	}
	for _, test := range fixture.Cases {
		t.Run(test.Name, func(t *testing.T) {
			if got := Evaluate(test.Input); got != test.Expected {
				t.Fatalf("got=%+v want=%+v", got, test.Expected)
			}
		})
	}
}
