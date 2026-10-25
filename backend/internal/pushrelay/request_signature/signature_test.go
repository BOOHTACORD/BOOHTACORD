package requestsignature

import (
	"crypto/ed25519"
	"crypto/rand"
	"github.com/google/uuid"
	"testing"
	"time"
)

func TestSignatureBindsEveryBoundaryAndDoesNotNormalizeAmbiguousInputs(t *testing.T) {
	public, private, _ := ed25519.GenerateKey(rand.Reader)
	now := time.Now().UTC().Truncate(time.Second)
	request := Request{Method: "POST", Path: "/v1/grants", Role: "device", Subject: uuid.NewString(), Timestamp: now.Format(time.RFC3339), Nonce: uuid.NewString(), Body: []byte(`{"generation":1}`)}
	signature, err := Sign(private, request)
	if err != nil {
		t.Fatal(err)
	}
	request.Signature = signature
	if Verify(public, request, now) != nil {
		t.Fatal("valid request rejected")
	}
	for _, mutate := range []func(*Request){
		func(r *Request) { r.Method = "DELETE" }, func(r *Request) { r.Path = "/v1/jobs" }, func(r *Request) { r.Role = "tenant" }, func(r *Request) { r.Subject = uuid.NewString() }, func(r *Request) { r.Nonce = uuid.NewString() }, func(r *Request) { r.Body = []byte("changed") }, func(r *Request) { r.Timestamp = now.Add(time.Second).Format(time.RFC3339) },
	} {
		copy := request
		mutate(&copy)
		if Verify(public, copy, now) == nil {
			t.Fatal("signature failed to bind request")
		}
	}
	if Verify(public, request, now.Add(61*time.Second)) == nil || Verify(public, request, now.Add(-61*time.Second)) == nil {
		t.Fatal("expired signature")
	}
	for _, path := range []string{"/v1//grants", "/v1/grants?token=x", "/v1/grants#x", "/v1/%2fgrants", "/v1/../grants", "/v1/\ngrants"} {
		copy := request
		copy.Path = path
		if _, err = Sign(private, copy); err == nil {
			t.Fatal("ambiguous path", path)
		}
	}
	for _, mutate := range []func(*Request){func(r *Request) { r.Subject = "{" + r.Subject + "}" }, func(r *Request) { r.Method = " POST" }, func(r *Request) { r.Role = "device\n" }, func(r *Request) { r.Timestamp += " " }, func(r *Request) { r.Body = make([]byte, 16385) }} {
		copy := request
		mutate(&copy)
		if _, err = Sign(private, copy); err == nil {
			t.Fatal("noncanonical request accepted")
		}
	}
	if _, err = Sign(nil, request); err == nil {
		t.Fatal("nil key accepted")
	}
	if Verify(nil, request, now) == nil {
		t.Fatal("nil public key accepted")
	}
}
