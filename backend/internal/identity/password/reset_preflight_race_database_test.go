package password_test

import (
	"context"
	"crypto/sha256"
	"errors"
	"sync"
	"testing"
	"time"

	reset "voice-platform/backend/internal/identity/complete_password_reset"
	resetpostgres "voice-platform/backend/internal/identity/complete_password_reset/postgres"
	"voice-platform/backend/internal/identity/password"
)

type pausedResetPreflight struct {
	resetpostgres.Repository
	ready   chan struct{}
	proceed <-chan struct{}
}

func (store pausedResetPreflight) Preflight(ctx context.Context, digest [sha256.Size]byte) error {
	if err := store.Repository.Preflight(ctx, digest); err != nil {
		return err
	}
	store.ready <- struct{}{}
	select {
	case <-store.proceed:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

func TestResetPreflightDoesNotLockRowAndConsumeRechecksExpiry(t *testing.T) {
	f := newResetPreflightFixture(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	other, err := f.pool.Acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer other.Release()
	ready, proceed := make(chan struct{}, 1), make(chan struct{})
	var once sync.Once
	release := func() { once.Do(func() { close(proceed) }) }
	var workers sync.WaitGroup
	defer func() { release(); cancel(); workers.Wait() }()
	store := pausedResetPreflight{f.repository, ready, proceed}
	count := password.CountDerivationsForTest(t)
	result := make(chan error, 1)
	workers.Add(1)
	go func() {
		defer workers.Done()
		result <- reset.New(store).Complete(ctx, reset.Input{Token: f.token.Token, Password: preflightNewPassword})
	}()
	select {
	case <-ready:
	case <-ctx.Done():
		t.Fatal("preflight did not complete")
	}
	update, stop := context.WithTimeout(ctx, time.Second)
	_, err = other.Exec(update, `UPDATE password_resets SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, f.token.Digest[:])
	stop()
	if err != nil {
		t.Fatal("preflight retained a lock/transaction across KDF boundary")
	}
	before := f.state(t)
	release()
	select {
	case err := <-result:
		if !errors.Is(err, reset.ErrInvalidOrExpired) {
			t.Fatal("final consume accepted token that expired after preflight")
		}
	case <-ctx.Done():
		t.Fatal("reset did not complete")
	}
	workers.Wait()
	if count() != 1 || f.state(t) != before {
		t.Fatal("final expiry failure changed state or skipped the real TOCTOU KDF")
	}
}

func TestTwoResetServicesPreflightValidButOnlyOneCommits(t *testing.T) {
	f := newResetPreflightFixture(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	ready, proceed := make(chan struct{}, 2), make(chan struct{})
	var once sync.Once
	release := func() { once.Do(func() { close(proceed) }) }
	var workers sync.WaitGroup
	defer func() { release(); cancel(); workers.Wait() }()
	store := pausedResetPreflight{f.repository, ready, proceed}
	count := password.CountDerivationsForTest(t)
	candidates := []string{preflightNewPassword, "synthetic concurrent replacement password"}
	type outcome struct {
		index int
		err   error
	}
	results := make(chan outcome, 2)
	for index, candidate := range candidates {
		workers.Add(1)
		go func(index int, candidate string) {
			defer workers.Done()
			results <- outcome{index, reset.New(store).Complete(ctx, reset.Input{Token: f.token.Token, Password: candidate})}
		}(index, candidate)
	}
	for range 2 {
		select {
		case <-ready:
		case <-ctx.Done():
			t.Fatal("both preflights did not finish")
		}
	}
	release()
	success, reused, winner := 0, 0, -1
	for range 2 {
		select {
		case result := <-results:
			switch {
			case result.err == nil:
				success++
				winner = result.index
			case errors.Is(result.err, reset.ErrInvalidOrExpired):
				reused++
			default:
				t.Fatal("unexpected concurrent reset error")
			}
		case <-ctx.Done():
			t.Fatal("concurrent reset did not complete")
		}
	}
	workers.Wait()
	if success != 1 || reused != 1 || count() != 2 {
		t.Fatal("two successful preflights did not preserve final one-use atomicity")
	}
	f.assertApplied(t, candidates[winner])
	if valid, err := password.Verify(ctx, candidates[1-winner], f.state(t).hash); err != nil || valid {
		t.Fatal("losing candidate changed the committed password")
	}
}
