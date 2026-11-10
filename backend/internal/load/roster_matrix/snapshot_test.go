package rostermatrix

import "testing"

func TestEmptyFixtureRosterRequiresEveryExpectedRoom(t *testing.T) {
	rooms := []string{"11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"}
	valid := `{"channels":[{"channel_id":"22222222-2222-4222-8222-222222222222","participants":[]},{"channel_id":"11111111-1111-4111-8111-111111111111","participants":[]}]}`
	if err := ValidateEmptySnapshot([]byte(valid), rooms); err != nil {
		t.Fatal(err)
	}
	for _, body := range []string{
		`{"channels":[]}`,
		`{"channels":[{"channel_id":"11111111-1111-4111-8111-111111111111","participants":[]},{"channel_id":"11111111-1111-4111-8111-111111111111","participants":[]}]}`,
		`{"channels":[{"channel_id":"11111111-1111-4111-8111-111111111111","participants":[{}]},{"channel_id":"22222222-2222-4222-8222-222222222222","participants":[]}]}`,
		`{"channels":null}`,
		`{"channels":[{"channel_id":"11111111-1111-4111-8111-111111111111","participants":null},{"channel_id":"22222222-2222-4222-8222-222222222222","participants":[]}]}`,
		`{"channels":[`,
	} {
		if ValidateEmptySnapshot([]byte(body), rooms) == nil {
			t.Fatal("accepted incomplete, duplicate, populated or malformed snapshot")
		}
	}
}

func TestEmptyFixtureRequiresRealEmptyArray(t *testing.T) {
	if ValidateEmptySnapshot([]byte(`{"channels":[]}`), nil) != nil {
		t.Fatal("empty room fixture was rejected")
	}
	if ValidateEmptySnapshot([]byte(`{}`), nil) == nil {
		t.Fatal("missing rooms must not be treated as empty")
	}
}
