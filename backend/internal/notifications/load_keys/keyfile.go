package loadkeys

import (
	"encoding/base64"
	"errors"
	"io"
	"os"
	"strings"
)

var ErrUnavailable = errors.New("notification keys unavailable")

// Load32 accepts a bounded operator-owned base64 key file, never request input.
func Load32(path string) ([]byte, error) {
	if path == "" {
		return nil, ErrUnavailable
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, ErrUnavailable
	}
	defer file.Close()
	raw, err := io.ReadAll(io.LimitReader(file, 1025))
	if err != nil || len(raw) > 1024 {
		return nil, ErrUnavailable
	}
	value := strings.TrimSpace(string(raw))
	for _, encoding := range []*base64.Encoding{base64.RawURLEncoding.Strict(), base64.URLEncoding.Strict(), base64.StdEncoding.Strict()} {
		key, err := encoding.DecodeString(value)
		if err == nil && len(key) == 32 {
			return key, nil
		}
	}
	return nil, ErrUnavailable
}
