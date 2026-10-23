package exercise_actor

import (
	"context"
	"errors"
	"fmt"
	"voice-platform/backend/internal/load/validate_target"
)

// ADR-003: ten attempts per five minutes per source IP. This independent profile
// uses one source; the normal 100-source profile does not bypass this quota.
// SEC-001 admits at most eight checks per account in a short window. Use fresh
// unknown fixture logins for source attempts 9..11, so an exhausted account
// cannot hide whether the independent IP admission still rejects attempt 11.
func (a *Actor) SharedNAT(ctx context.Context) error {
	a.Client = validate_target.ClientFrom(199)
	for attempt := 0; attempt < 11; attempt++ {
		expected, name := 204, "login"
		login := a.Account.Login
		if attempt >= 8 {
			login = fmt.Sprintf("qa_load_nat_probe_%02d", attempt)
			expected = 401
		}
		if attempt == 10 {
			expected, name = 429, "nat_limit"
		}
		var result any
		var denied struct {
			Error struct {
				Code string `json:"code"`
			} `json:"error"`
		}
		if expected >= 400 {
			result = &denied
		}
		if err := a.Request(ctx, name, "POST", "/auth/login", map[string]string{"login": login, "password": a.Account.Password}, expected, result); err != nil {
			return err
		}
		if expected == 429 {
			if denied.Error.Code != "RATE_LIMITED" {
				return errors.New("unexpected shared-source quota response")
			}
			return nil
		}
		if expected == 401 {
			if denied.Error.Code != "UNAUTHENTICATED" {
				return errors.New("unexpected unknown-account response")
			}
			continue
		}
		if err := a.Request(ctx, "logout", "POST", "/auth/logout", nil, 204, nil); err != nil {
			return err
		}
	}
	return nil
}
