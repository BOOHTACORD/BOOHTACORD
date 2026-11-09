package rostermatrix

import (
	"context"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/load/validate_target"
)

type rejectTransport struct{ t *testing.T }

func (r rejectTransport) RoundTrip(*http.Request) (*http.Response, error) {
	r.t.Fatal("foreign target was contacted")
	return nil, nil
}

func TestFixtureLoginChecksSessionIdentity(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/auth/login":
			if r.Method != http.MethodPost || r.Header.Get("Origin") == "" {
				t.Error("invalid login request")
			}
			http.SetCookie(w, &http.Cookie{Name: "session", Value: "fixture"})
			w.WriteHeader(http.StatusNoContent)
		case "/api/v1/auth/session":
			if _, err := r.Cookie("session"); err != nil {
				t.Error("session cookie missing")
			}
			_, _ = w.Write([]byte(`{"authenticated":true,"account_id":"fixture-account"}`))
		default:
			t.Error("unexpected path")
		}
	}))
	defer server.Close()
	client := server.Client()
	client.Jar, _ = cookiejar.New(nil)
	account := validate_target.Account{Login: "qa_load_000", Password: "fixture", ID: "fixture-account"}
	if err := Login(context.Background(), client, server.URL, account); err != nil {
		t.Fatal(err)
	}
	account.ID = "different-account"
	if err := Login(context.Background(), client, server.URL, account); err == nil {
		t.Fatal("accepted wrong session identity")
	}
	if err := Login(context.Background(), &http.Client{Transport: rejectTransport{t}}, "https://foreign.invalid", account); err == nil {
		t.Fatal("accepted foreign login target")
	}
}

func TestFixtureLoginRejectsRedirectBeforeSendingCredentialsAgain(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/unexpected" {
			t.Error("redirect was followed")
		}
		http.Redirect(w, r, "/unexpected", http.StatusTemporaryRedirect)
	}))
	defer server.Close()
	account := validate_target.Account{Login: "qa_load_000", Password: "fixture", ID: "fixture"}
	if Login(context.Background(), server.Client(), server.URL, account) == nil {
		t.Fatal("redirect accepted")
	}
}
