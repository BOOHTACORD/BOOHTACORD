// Package supportbridge sends only the consented support outbox, independently of telemetry.
package supportbridge

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

var ErrGateway = errors.New("product support gateway unavailable")

type Client struct {
	endpoint string
	key      ed25519.PrivateKey
	http     *http.Client
}

func NewClient(endpoint string, seed []byte) (Client, error) {
	u, err := url.Parse(endpoint)
	if err != nil || u.Host == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Path != "/support/v1" ||
		(u.Scheme != "https" && (u.Scheme != "http" || (u.Hostname() != "127.0.0.1" && u.Hostname() != "localhost"))) || len(seed) != 32 {
		return Client{}, ErrGateway
	}
	return Client{endpoint, ed25519.NewKeyFromSeed(seed), &http.Client{Timeout: 90 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}}, nil
}
func (c Client) opaque(domain, value string) string {
	mac := hmac.New(sha256.New, c.key.Seed())
	mac.Write([]byte("boohtacord-support/" + domain + "/v1\x00" + value))
	return hex.EncodeToString(mac.Sum(nil)[:16])
}
func (c Client) request(ctx context.Context, method, path string, body []byte, result any) error {
	request, err := http.NewRequestWithContext(ctx, method, c.endpoint+path, bytes.NewReader(body))
	if err != nil {
		return ErrGateway
	}
	hash := sha256.Sum256(body)
	nonce := make([]byte, 16)
	if _, err = rand.Read(nonce); err != nil {
		return ErrGateway
	}
	stamp := strconv.FormatInt(time.Now().Unix(), 10)
	nonceText := hex.EncodeToString(nonce)
	canonical := strings.Join([]string{"boohtacord-support-v1", method, request.URL.RequestURI(), stamp, nonceText, hex.EncodeToString(hash[:])}, "\n")
	request.Header.Set("X-Support-Key", hex.EncodeToString(c.key.Public().(ed25519.PublicKey)))
	request.Header.Set("X-Support-Time", stamp)
	request.Header.Set("X-Support-Nonce", nonceText)
	request.Header.Set("X-Support-Signature", base64.StdEncoding.EncodeToString(ed25519.Sign(c.key, []byte(canonical))))
	request.Header.Set("X-Support-Content-SHA256", hex.EncodeToString(hash[:]))
	request.Header.Set("Content-Type", "application/json")
	if method == "PUT" {
		request.Header.Set("Content-Type", "application/octet-stream")
	}
	response, err := c.http.Do(request)
	if err != nil {
		return ErrGateway
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return ErrGateway
	}
	if result != nil && json.NewDecoder(io.LimitReader(response.Body, 1_000_001)).Decode(result) != nil {
		return ErrGateway
	}
	return nil
}
