package requestsignature

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
)

// ErrInvalid is returned for any malformed request field.
var ErrInvalid = errors.New("invalid request signature input")

// Request is the signed notification-relay payload.
type Request struct {
	Method    string
	Path      string
	Role      string
	Subject   string
	Timestamp string
	Nonce     string
	Signature string
	Body      []byte
}

var (
	roleTenant = "tenant"
	roleDevice = "device"
	methodPost = "POST"
	methodGet  = "GET"
	methodDel  = "DELETE"
	methodPut  = "PUT"
	pathRe     = regexp.MustCompile(`^/v1/[a-z0-9_/-]+$`)
	maxBody    = 16384
	maxField   = 256
)

// Canonical renders the domain-separated canonical byte form.
func Canonical(r Request) ([]byte, error) {
	role := r.Role
	switch role {
	case roleTenant, roleDevice:
	default:
		return nil, ErrInvalid
	}
	method := r.Method
	switch method {
	case methodPost, methodGet, methodDel, methodPut:
	default:
		return nil, ErrInvalid
	}
	path := r.Path
	if len(path) > maxField || !pathRe.MatchString(path) || strings.Contains(path, "//") || strings.Contains(path, "/./") || strings.Contains(path, "/../") || strings.HasSuffix(path, "/.") || strings.HasSuffix(path, "/..") {
		return nil, ErrInvalid
	}
	for _, c := range path {
		if c < 0x21 || c > 0x7e {
			return nil, ErrInvalid
		}
	}
	subject, err := canonicalUUID(r.Subject)
	if err != nil {
		return nil, err
	}
	nonce, err := canonicalUUID(r.Nonce)
	if err != nil {
		return nil, err
	}
	ts, err := canonicalTimestamp(r.Timestamp)
	if err != nil {
		return nil, err
	}
	if len(r.Body) > maxBody {
		return nil, ErrInvalid
	}
	h := sha256.Sum256(r.Body)
	bodyHex := hex.EncodeToString(h[:])
	fields := []string{"notification-relay-request/v1", role, subject, method, path, ts, nonce, bodyHex}
	return []byte(strings.Join(fields, "\n")), nil
}

func canonicalUUID(s string) (string, error) {
	if len(s) > maxField {
		return "", ErrInvalid
	}
	u, err := uuid.Parse(s)
	if err != nil || u == uuid.Nil || s != u.String() {
		return "", ErrInvalid
	}
	return strings.ToLower(u.String()), nil
}

func canonicalTimestamp(s string) (string, error) {
	if len(s) > maxField {
		return "", ErrInvalid
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil || t.Nanosecond() != 0 {
		return "", ErrInvalid
	}
	c := t.UTC().Format(time.RFC3339)
	if c != s {
		return "", ErrInvalid
	}
	return c, nil
}
