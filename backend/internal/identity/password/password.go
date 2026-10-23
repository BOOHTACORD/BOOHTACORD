package password

import (
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
var argonSlots = make(chan struct{}, 4)

// The private seam allows tests to count real KDF executions across the login
// service. Production always uses the supported Go Argon2id implementation.
var deriveKey = argon2.IDKey
var dummyHash = initializeDummyHash(Hash)

func initializeDummyHash(generate func(string) (string, error)) string {
	encoded, err := generate("unmatchable-dummy-password")
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

func Hash(plainText string) (string, error) {
	argonSlots <- struct{}{}
	defer func() { <-argonSlots }()
	salt := make([]byte, saltLength)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return "", fmt.Errorf("generate password salt: %w", err)
	}

	derivedKey := deriveKey([]byte(plainText), salt, iterations, memoryKiB, parallelism, keyLength)
	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memoryKiB,
		iterations,
		parallelism,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(derivedKey),
	), nil
}

func Verify(plainText, encoded string) (bool, error) {
	argonSlots <- struct{}{}
	defer func() { <-argonSlots }()
	salt, storedKey, err := decode(encoded)
	if err != nil {
		return false, err
	}

	candidate := deriveKey([]byte(plainText), salt, iterations, memoryKiB, parallelism, keyLength)
	return subtle.ConstantTimeCompare(candidate, storedKey) == 1, nil
}

// VerifyUnknown performs the same Argon2id work as a normal verification for
// an account that does not exist. A match can never authorize an account; only
// errors propagate so a broken dummy cannot silently disable the check.
func VerifyUnknown(plainText string) error {
	_, err := Verify(plainText, dummyHash)
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
