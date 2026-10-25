package acceptnotification

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

var ErrNotFound = errors.New("relay notification unavailable")

type Query struct {
	GrantID string `json:"grant_id"`
	JobRef  string `json:"job_ref"`
}

func (s Service) Status(ctx context.Context, request signature.Request, in Query, now time.Time) (Status, error) {
	var decoded Query
	if !receipt.ID(in.GrantID) || !receipt.ID(in.JobRef) || request.Method != "POST" || request.Path != "/v1/receipts" || json.Unmarshal(request.Body, &decoded) != nil || decoded != in {
		return Status{}, ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Status{}, err
	}
	defer rollback(tx)
	if _, err = auth.Lock(ctx, tx); err != nil {
		return Status{}, err
	}
	if err = auth.Verify(ctx, tx, request, "tenant", false, now); err != nil {
		return Status{}, err
	}
	if _, err = destination(ctx, tx, in.GrantID, request.Subject, s.Namespace, now); err != nil {
		return Status{}, err
	}
	out := Status{Version: 1, JobRef: in.JobRef}
	err = tx.QueryRow(ctx, `SELECT state,expires_at FROM relay_jobs WHERE grant_id=$1::uuid AND job_ref=$2::uuid AND tenant_id=$3::uuid`, in.GrantID, in.JobRef, request.Subject).Scan(&out.State, &out.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return out, ErrNotFound
	}
	if err != nil {
		return out, err
	}
	if out.State == "pending" || out.State == "claimed" || out.State == "retry" {
		out.State = "accepted_by_relay"
	}
	return out, tx.Commit(ctx)
}
