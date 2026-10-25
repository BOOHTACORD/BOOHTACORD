package registerdevice

import (
	"crypto/ecdh"
	"encoding/base64"
	"github.com/google/uuid"
	"net/url"
)

func validID(raw string) bool {
	id, err := uuid.Parse(raw)
	return err == nil && id != uuid.Nil && id.String() == raw
}
func Validate(in Input) error {
	if !validID(in.AccountID) || !validID(in.InstanceID) || in.SessionDigest == [32]byte{} || in.ConsentVersion != 1 || in.ExpectedGeneration < 0 || in.ExpectedGeneration >= 1000000000 {
		return ErrInvalid
	}
	if in.ExpectedGeneration == 0 && in.ID != "" || in.ExpectedGeneration > 0 && !validID(in.ID) {
		return ErrInvalid
	}
	if in.Namespace != "staging" && in.Namespace != "production" {
		return ErrInvalid
	}
	if in.Permission != "granted" && in.Permission != "provisional" {
		return ErrInvalid
	}
	switch in.Transport {
	case "web_push":
		if in.Subscription == nil || in.Permission != "granted" {
			return ErrInvalid
		}
		sub := in.Subscription
		if len(sub.Endpoint) > 2048 || len(sub.Keys.P256DH) > 128 || len(sub.Keys.Auth) > 64 {
			return ErrInvalid
		}
		target, err := url.Parse(sub.Endpoint)
		if err != nil || target.Scheme != "https" || target.Host == "" || target.User != nil || target.Fragment != "" {
			return ErrInvalid
		}
		key, err := base64.RawURLEncoding.Strict().DecodeString(sub.Keys.P256DH)
		if err != nil {
			return ErrInvalid
		}
		if _, err = ecdh.P256().NewPublicKey(key); err != nil {
			return ErrInvalid
		}
		auth, err := base64.RawURLEncoding.Strict().DecodeString(sub.Keys.Auth)
		if err != nil || len(auth) != 16 {
			return ErrInvalid
		}
	case "mobile_relay":
		if in.Subscription != nil {
			return ErrInvalid
		}
	default:
		return ErrInvalid
	}
	return nil
}
