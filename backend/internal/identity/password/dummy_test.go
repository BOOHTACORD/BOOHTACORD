package password

import (
	"context"
	"errors"
	"testing"
)

func TestSecurity20261022DummyHashMustBeValid(t *testing.T) {
	salt, key, err := decode(dummyHash)
	if err != nil {
		t.Fatal("process dummy hash does not satisfy the supported password format")
	}
	if len(salt) != saltLength || len(key) != int(keyLength) {
		t.Fatal("process dummy hash has incompatible salt or key size")
	}
	valid, err := Verify(context.Background(), "synthetic incorrect candidate", dummyHash)
	if err != nil || valid {
		t.Fatal("dummy verification must perform a supported negative check")
	}
}

func TestDummyInitializationFailsClosedWithoutExposingHashOrCause(t *testing.T) {
	for _, generate := range []func(context.Context, string) (string, error){
		func(context.Context, string) (string, error) { return "", errors.New("synthetic internal cause") },
		func(context.Context, string) (string, error) { return "synthetic malformed hash", nil },
	} {
		func() {
			defer func() {
				if got := recover(); got != "password dummy initialization failed" {
					t.Fatal("invalid dummy initialization must stop startup with a fixed safe signal")
				}
			}()
			initializeDummyHash(generate)
		}()
	}
}

func TestVerifyUnknownReportsInvalidDummy(t *testing.T) {
	original := dummyHash
	t.Cleanup(func() { dummyHash = original })
	dummyHash = "synthetic invalid hash"
	if err := VerifyUnknown(context.Background(), "synthetic password"); !errors.Is(err, ErrInvalidHash) {
		t.Fatal("invalid dummy must not be silently ignored")
	}
}
