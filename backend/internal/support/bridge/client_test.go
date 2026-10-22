package supportbridge

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGatewayProofBindsPayloadAndDoesNotSendBrowserCredentials(t *testing.T) {
	seed := make([]byte, 32)
	valid := false
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		pub, _ := hex.DecodeString(r.Header.Get("X-Support-Key"))
		sig, _ := base64.StdEncoding.DecodeString(r.Header.Get("X-Support-Signature"))
		hash := sha256.Sum256(body)
		canonical := "boohtacord-support-v1\nPOST\n/support/v1/messages\n" + r.Header.Get("X-Support-Time") + "\n" + r.Header.Get("X-Support-Nonce") + "\n" + hex.EncodeToString(hash[:])
		valid = ed25519.Verify(pub, []byte(canonical), sig) && r.Header.Get("Cookie") == "" && r.Header.Get("Authorization") == ""
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"accepted":true}`))
	}))
	defer server.Close()
	client, err := NewClient(server.URL+"/support/v1", seed)
	if err != nil {
		t.Fatal(err)
	}
	if err := client.request(context.Background(), "POST", "/messages", []byte(`{"synthetic":true}`), nil); err != nil || !valid {
		t.Fatal("invalid gateway authentication", err)
	}
}
func TestGatewayEndpointNeverAcceptsArbitraryPlainHTTP(t *testing.T) {
	for _, endpoint := range []string{"http://example.com/support/v1", "https://user:password@example.com/support/v1", "https://example.com/support/v1?token=x"} {
		if _, err := NewClient(endpoint, make([]byte, 32)); err == nil {
			t.Fatal("unsafe endpoint accepted")
		}
	}
}
