package installation

import (
	"bytes"
	"github.com/google/uuid"
	"testing"
)

func TestIdentityScopesUsersAndSeparatesTransportFromProof(t *testing.T) {
	a, err := New()
	if err != nil {
		t.Fatal(err)
	}
	b, _ := New()
	if uuid.MustParse(a.ID).Version() != 4 || len(a.Key) != 32 {
		t.Fatal("invalid identity")
	}
	account := "00000000-0000-4000-8000-000000000001"
	if a.Pseudonym("user", account) == b.Pseudonym("user", account) {
		t.Fatal("cross-install user collision")
	}
	if a.Pseudonym("user", account) != a.Pseudonym("user", account) || a.Pseudonym("user", account) == a.Pseudonym("session", account) {
		t.Fatal("unstable or unseparated identity")
	}
	if a.ProofKey() == "" || a.ProofKey() == a.Pseudonym("user", account) {
		t.Fatal("invalid causal key")
	}
	original := bytes.Clone(a.Key)
	a.Credential = "rotated"
	if !bytes.Equal(original, a.Key) {
		t.Fatal("transport rotation changed pseudonym key")
	}
	if a.Valid() != nil {
		t.Fatal("valid identity rejected")
	}
	a.Key = nil
	if a.Valid() == nil {
		t.Fatal("corruption accepted")
	}
}
