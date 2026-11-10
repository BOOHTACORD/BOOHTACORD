package rostermatrix

import (
	"testing"
	"time"
)

func TestMessageIDAcceptsOnlyValidCreatedHints(t *testing.T) {
	const id = "11111111-1111-4111-8111-111111111111"
	value, err := MessageID([]byte(`{"kind":"message.created","payload":{"message_id":"` + id + `"}}`))
	if err != nil || value != id {
		t.Fatalf("valid hint: %q %v", value, err)
	}
	if _, err := MessageID([]byte(`{"kind":"message.created","payload":{"message_id":"bad"}}`)); err == nil {
		t.Fatal("invalid message id accepted")
	}
	if value, err := MessageID([]byte(`{"kind":"connection.ready","payload":{}}`)); err != nil || value != "" {
		t.Fatal("non-message hint misclassified")
	}
}

func TestMessageOccurredAtRequiresValidServerTimestamp(t *testing.T) {
	frame := []byte(`{"kind":"message.created","occurred_at":"2026-11-09T10:00:00Z","payload":{}}`)
	got, err := MessageOccurredAt(frame)
	if err != nil || got.Format(time.RFC3339) != "2026-11-09T10:00:00Z" {
		t.Fatalf("timestamp: %v %v", got, err)
	}
	if _, err := MessageOccurredAt([]byte(`{"kind":"message.created","payload":{}}`)); err == nil {
		t.Fatal("missing timestamp accepted")
	}
}
