package password

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	memoryKiB   uint32 = 19456
	iterations  uint32 = 2
	parallelism uint8  = 1
	saltLength         = 16
	keyLength   uint32 = 32
)

var ErrInvalidHash = errors.New("invalid password hash")

// The private seam allows tests to count real KDF executions across the login
// service. Production always uses the supported Go Argon2id implementation.
var deriveKey = argon2.IDKey
var dummyHash = initializeDummyHash(Hash)

func initializeDummyHash(generate func(context.Context, string) (string, error)) string {
	encoded, err := generate(context.Background(), "unmatchable-dummy-password")
	if err == nil {
		_, _, err = decode(encoded)
	}
	if err != nil {
		// Stop before serving authentication with an invalid dummy. Do not put
		// the underlying cause, salt or hash into the startup diagnostic.
		panic("password dummy initialization failed")
	}
	return encoded
}

func Hash(ctx context.Context, plainText string) (string, error) {
	if err := ctx.Err(); err != nil {
		kdfAdmission.cancelled.Inc()
		return "", err
	}
	salt := make([]byte, saltLength)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return "", fmt.Errorf("generate password salt: %w", err)
	}

	derivedKey, err := derive(ctx, plainText, salt)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memoryKiB,
		iterations,
		parallelism,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(derivedKey),
	), nil
}

func Verify(ctx context.Context, plainText, encoded string) (bool, error) {
	if err := ctx.Err(); err != nil {
		kdfAdmission.cancelled.Inc()
		return false, err
	}
	salt, storedKey, err := decode(encoded)
	if err != nil {
		return false, err
	}

	candidate, err := derive(ctx, plainText, salt)
	if err != nil {
		return false, err
	}
	return subtle.ConstantTimeCompare(candidate, storedKey) == 1, nil
}

// VerifyUnknown performs the same Argon2id work as a normal verification for
// an account that does not exist. A match can never authorize an account; only
// errors propagate so a broken dummy cannot silently disable the check.
func VerifyUnknown(ctx context.Context, plainText string) error {
	_, err := Verify(ctx, plainText, dummyHash)
	return err
}

func decode(encoded string) ([]byte, []byte, error) {
	parts := strings.Split(encoded, "$")
	wantParameters := fmt.Sprintf("m=%d,t=%d,p=%d", memoryKiB, iterations, parallelism)
	if len(parts) != 6 || parts[0] != "" || parts[1] != "argon2id" || parts[2] != "v=19" || parts[3] != wantParameters {
		return nil, nil, ErrInvalidHash
	}

	salt, saltErr := base64.RawStdEncoding.DecodeString(parts[4])
	key, keyErr := base64.RawStdEncoding.DecodeString(parts[5])
	if saltErr != nil || keyErr != nil || len(salt) != saltLength || len(key) != int(keyLength) {
		return nil, nil, ErrInvalidHash
	}
	return salt, key, nil
}
