package webpush

import (
	"bytes"
	"crypto/ecdh"
	"encoding/base64"
	"errors"
	"net/mail"
	"net/url"
	"strings"
)

var ErrConfiguration = errors.New("invalid VAPID configuration")

func ValidateVAPID(public, private, contact string) error {
	if len(contact) == 0 || len(contact) > 256 || len(public) > 128 || len(private) > 64 {
		return ErrConfiguration
	}
	if !isValidContact(contact) {
		return ErrConfiguration
	}
	pubBytes, err := base64.RawURLEncoding.Strict().DecodeString(public)
	if err != nil || len(pubBytes) != 65 || pubBytes[0] != 0x04 {
		return ErrConfiguration
	}
	privBytes, err := base64.RawURLEncoding.Strict().DecodeString(private)
	if err != nil || len(privBytes) != 32 {
		return ErrConfiguration
	}
	key, err := ecdh.P256().NewPrivateKey(privBytes)
	if err != nil {
		return ErrConfiguration
	}
	derived := key.PublicKey().Bytes()
	if !bytes.Equal(derived, pubBytes) {
		return ErrConfiguration
	}
	return nil
}

func isValidContact(contact string) bool {
	u, err := url.Parse(contact)
	if err != nil || u.Scheme == "" {
		return false
	}
	switch u.Scheme {
	case "mailto":
		addr, err := mail.ParseAddress(u.Opaque)
		if err != nil || addr.Address != u.Opaque || !strings.EqualFold(addr.Name, "") {
			return false
		}
		if u.User != nil || u.Fragment != "" || u.RawQuery != "" {
			return false
		}
		return true
	case "https":
		if u.Host == "" || u.User != nil || u.Fragment != "" {
			return false
		}
		return true
	default:
		return false
	}
}
