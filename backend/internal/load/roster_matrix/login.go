package rostermatrix

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"voice-platform/backend/internal/load/validate_target"
)

// Login is called only after the enclosing load runner has verified ownership.
func Login(ctx context.Context, client *http.Client, origin string, account validate_target.Account) error {
	if validate_target.Loopback(origin, true) != nil {
		return errors.New("login target must be loopback TLS")
	}
	client = noRedirect(client)
	data, err := json.Marshal(map[string]string{"login": account.Login, "password": account.Password})
	if err != nil {
		return errors.New("invalid synthetic account")
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, origin+"/api/v1/auth/login", bytes.NewReader(data))
	if err != nil {
		return errors.New("invalid login request")
	}
	request.Header.Set("Origin", origin)
	request.Header.Set("Content-Type", "application/json")
	response, err := client.Do(request)
	if err != nil {
		return errors.New("fixture login failed")
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 4096))
	response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		return errors.New("fixture login rejected")
	}
	request, err = http.NewRequestWithContext(ctx, http.MethodGet, origin+"/api/v1/auth/session", nil)
	if err != nil {
		return errors.New("invalid session request")
	}
	response, err = client.Do(request)
	if err != nil {
		return errors.New("fixture session check failed")
	}
	defer response.Body.Close()
	var session struct {
		ID            string `json:"account_id"`
		Authenticated bool   `json:"authenticated"`
	}
	if response.StatusCode != http.StatusOK || json.NewDecoder(io.LimitReader(response.Body, 4096)).Decode(&session) != nil || !session.Authenticated || session.ID != account.ID {
		return errors.New("fixture session identity mismatch")
	}
	return nil
}

func noRedirect(client *http.Client) *http.Client {
	copy := *client
	copy.CheckRedirect = func(*http.Request, []*http.Request) error { return errors.New("fixture redirect refused") }
	return &copy
}
