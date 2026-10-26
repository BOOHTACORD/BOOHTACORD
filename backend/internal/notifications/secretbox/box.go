package secretbox

import (
	"crypto/aes"
	"crypto/cipher"
	"errors"
)

const (
	maxPlaintextLen  = 16384 // max plaintext bytes accepted by Seal.
	minCiphertextLen = 28    // nonce(12)+scope-tag(16).
	maxCiphertextLen = 16412 // minCiphertextLen + maxPlaintextLen.
	maxScopeLen      = 2048  // max scope bytes accepted by Seal/Open.
)

var (
	errKeyLength  = errors.New("secretbox: invalid key length")
	errPlaintext  = errors.New("secretbox: invalid plaintext size")
	errCiphertext = errors.New("secretbox: invalid ciphertext size")
	errScope      = errors.New("secretbox: invalid scope")
	errDecrypt    = errors.New("secretbox: failed to open sealed data")
)

// Box is a scoped AEAD backed by AES-GCM with random nonces.
type Box struct {
	aead cipher.AEAD
}

// New returns a Box bound to key. key must be exactly 32 bytes.
func New(key []byte) (*Box, error) {
	if len(key) != 32 {
		return nil, errKeyLength
	}
	c, err := aes.NewCipher(key)
	if err != nil {
		return nil, errKeyLength
	}
	aead, err := cipher.NewGCMWithRandomNonce(c)
	if err != nil {
		return nil, errKeyLength
	}
	return &Box{aead: aead}, nil
}

// Seal encrypts plaintext under scope and returns the ciphertext.
func (b *Box) Seal(plaintext []byte, scope string) ([]byte, error) {
	if len(plaintext) < 1 || len(plaintext) > maxPlaintextLen {
		return nil, errPlaintext
	}
	if len(scope) < 1 || len(scope) > maxScopeLen {
		return nil, errScope
	}
	// nonce is nil: the random-nonce AEAD generates and prepends it.
	return b.aead.Seal(nil, nil, plaintext, []byte(scope)), nil
}

// Open decrypts ciphertext produced by Seal under scope.
func (b *Box) Open(ciphertext []byte, scope string) ([]byte, error) {
	if len(ciphertext) < minCiphertextLen || len(ciphertext) > maxCiphertextLen {
		return nil, errCiphertext
	}
	if len(scope) < 1 || len(scope) > maxScopeLen {
		return nil, errScope
	}
	out, err := b.aead.Open(nil, nil, ciphertext, []byte(scope))
	if err != nil {
		return nil, errDecrypt
	}
	return out, nil
}
