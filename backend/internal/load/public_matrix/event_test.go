package publicmatrix

import "testing"

func testFrame(kind, payload string) []byte {
	return []byte(`{"event_id":"11111111-1111-4111-8111-111111111111","occurred_at":"2026-11-09T00:00:00Z","kind":"` + kind + `","payload":` + payload + `}`)
}

func TestPublicEventsRejectPrivateOrUnknownPayloads(t *testing.T) {
	for _, raw := range [][]byte{
		testFrame("voice.roster.snapshot", `{}`),
		testFrame("message.created", `{}`),
		testFrame("maintenance.snapshot", `{"active":false}`),
		testFrame("connection.ready", `{"private":"data"}`),
	} {
		if _, err := Classify(raw); err == nil {
			t.Fatal("invalid public event accepted")
		}
	}
	if _, err := Classify([]byte(`{"kind":"connection.ready","payload":{}}`)); err == nil {
		t.Fatal("missing envelope identity accepted")
	}
	if _, err := Classify([]byte(`{"event_id":"11111111-1111-4111-8111-111111111111","occurred_at":"2026-11-09T00:00:00Z","kind":"connection.ready","payload":{},"private":"data"}`)); err == nil {
		t.Fatal("unexpected envelope field accepted")
	}
	for _, raw := range [][]byte{
		testFrame("connection.ready", `{}`),
		testFrame("maintenance.snapshot", `{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}`),
		testFrame("maintenance.changed", `{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":2,"active":true}`),
	} {
		if _, err := Classify(raw); err != nil {
			t.Fatal(err)
		}
	}
}
