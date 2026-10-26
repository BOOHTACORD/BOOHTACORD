package secretbox

import (
	"bytes"
	"testing"
)

func TestCiphertextIsRandomAndScopeBound(t *testing.T) {
	box, err := New(bytes.Repeat([]byte{1}, 32))
	if err != nil {
		t.Fatal(err)
	}
	first, err := box.Seal([]byte("synthetic-route-secret"), "origin/installation/account/device/generation1")
	if err != nil {
		t.Fatal(err)
	}
	second, err := box.Seal([]byte("synthetic-route-secret"), "origin/installation/account/device/generation1")
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(first, second) || bytes.Contains(first, []byte("synthetic-route-secret")) {
		t.Fatal("deterministic or exposed secret")
	}
	got, err := box.Open(first, "origin/installation/account/device/generation1")
	if err != nil || string(got) != "synthetic-route-secret" {
		t.Fatal("roundtrip failed")
	}
	if _, err := box.Open(first, "origin/installation/account/device/generation2"); err == nil {
		t.Fatal("cross-generation ciphertext accepted")
	}
	first[len(first)-1] ^= 1
	if _, err := box.Open(first, "origin/installation/account/device/generation1"); err == nil {
		t.Fatal("tampered secret accepted")
	}
}
func TestKeysAndSizesFailClosed(t *testing.T) {
	if _, err := New([]byte("short")); err == nil {
		t.Fatal("weak key accepted")
	}
	box, _ := New(bytes.Repeat([]byte{1}, 32))
	other, _ := New(bytes.Repeat([]byte{2}, 32))
	cipher, _ := box.Seal([]byte("test"), "scope")
	if _, err := other.Open(cipher, "scope"); err == nil {
		t.Fatal("wrong key accepted")
	}
	if _, err := box.Seal(bytes.Repeat([]byte{1}, 20000), "scope"); err == nil {
		t.Fatal("unbounded secret accepted")
	}
	if _, err := box.Seal([]byte("test"), ""); err == nil {
		t.Fatal("unbound ciphertext accepted")
	}
}
