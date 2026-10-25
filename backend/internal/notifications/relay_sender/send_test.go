package relaysender

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"testing"
)

type doFunc func(*http.Request) (*http.Response, error)

func (f doFunc) Do(r *http.Request) (*http.Response, error) { return f(r) }
func TestLostRelayAcceptanceIsResolvedByStableReference(t *testing.T) {
	pool, sender, message, handler := paired(t)
	ctx := context.Background()
	sends, polls := 0, 0
	mux := handler.Routes()
	sender.client = doFunc(func(r *http.Request) (*http.Response, error) {
		if r.Header.Get("Cookie") != "" || r.Header.Get("Origin") != "" || r.URL.Host != "relay.example.invalid" {
			t.Fatal("ambient credential or wrong destination")
		}
		response := httptest.NewRecorder()
		mux.ServeHTTP(response, r)
		if r.URL.Path == "/v1/notifications" {
			sends++
			httptrace.ContextClientTrace(r.Context()).WroteRequest(httptrace.WroteRequestInfo{})
			if response.Code != 202 {
				t.Fatal(response.Code, response.Body.String())
			}
			return nil, context.DeadlineExceeded
		}
		polls++
		return response.Result(), nil
	})
	result := sender.Send(ctx, message)
	if result.Outcome != "accepted_by_relay" || sends != 1 || polls != 1 {
		t.Fatal(result, sends, polls)
	}
	result = sender.Send(ctx, message)
	if result.Outcome != "accepted_by_relay" {
		t.Fatal(result)
	}
	var jobs int
	if err := pool.QueryRow(ctx, `SELECT count(*)FROM relay_jobs WHERE kind='notification'`).Scan(&jobs); err != nil || jobs != 1 {
		t.Fatal("retry made another provider job", jobs, err)
	}
	sender.config.ServerOrigin = "https://clone.example.invalid"
	result = sender.Send(ctx, message)
	if result.Outcome != "permanent_failure" || sends != 2 {
		t.Fatal("wrong installation scope used HTTP", result, sends)
	}
}
func TestDefinitiveRelayRevokeInvalidatesOnlyTheScopedBinding(t *testing.T) {
	pool, sender, message, handler := paired(t)
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `UPDATE relay_grants SET state='revoked'`); err != nil {
		t.Fatal(err)
	}
	sender.client = doFunc(func(r *http.Request) (*http.Response, error) {
		response := httptest.NewRecorder()
		handler.Routes().ServeHTTP(response, r)
		return response.Result(), nil
	})
	if result := sender.Send(ctx, message); result.Outcome != "invalid_binding" {
		t.Fatal(result)
	}
}
