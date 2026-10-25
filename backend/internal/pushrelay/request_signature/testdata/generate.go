//go:build ignore

// Generate public interoperability vectors. The fixed seed is synthetic.
package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"flag"
	"os"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

func main() {
	output := flag.String("output", "", "exact output fixture path")
	flag.Parse()
	if *output == "" {
		panic("output path required")
	}
	seed := make([]byte, 32)
	for i := range seed {
		seed[i] = byte(i)
	}
	key := ed25519.NewKeyFromSeed(seed)
	request := signature.Request{Method: "POST", Path: "/v1/grants", Role: "device", Subject: "11111111-1111-4111-8111-111111111111", Timestamp: "2026-10-25T12:00:00Z", Nonce: "22222222-2222-4222-8222-222222222222", Body: []byte(`{"binding_id":"33333333-3333-4333-8333-333333333333","generation":1}`)}
	canonical, err := signature.Canonical(request)
	if err != nil {
		panic(err)
	}
	signed, err := signature.Sign(key, request)
	if err != nil {
		panic(err)
	}
	fixture := map[string]any{"version": 1, "purpose": "Synthetic test vector; never use this seed for any real key", "test_seed_hex": hex.EncodeToString(seed), "public_key": base64.RawURLEncoding.EncodeToString(key.Public().(ed25519.PublicKey)), "role": request.Role, "subject": request.Subject, "method": request.Method, "path": request.Path, "timestamp": request.Timestamp, "nonce": request.Nonce, "body_base64": base64.RawURLEncoding.EncodeToString(request.Body), "canonical_base64": base64.RawURLEncoding.EncodeToString(canonical), "signature": signed}
	raw, err := json.MarshalIndent(fixture, "", "  ")
	if err != nil {
		panic(err)
	}
	if err = os.WriteFile(*output, append(raw, '\n'), 0644); err != nil {
		panic(err)
	}
}
