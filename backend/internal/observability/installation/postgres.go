package installation

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
)

func Load(ctx context.Context, db *pgxpool.Pool) (Identity, error) {
	var i Identity
	err := db.QueryRow(ctx, `SELECT installation_id::text,pseudonym_key,enrollment_seed,mode,central_endpoint,credential,enrolled,last_accepted_at FROM installation_identity WHERE singleton=true`).Scan(&i.ID, &i.Key, &i.Seed, &i.Mode, &i.Endpoint, &i.Credential, &i.Enrolled, &i.LastAccepted)
	if err != nil || i.Valid() != nil {
		return Identity{}, errors.New("installation identity unavailable; external telemetry disabled")
	}
	return i, nil
}

func Save(ctx context.Context, db *pgxpool.Pool, i Identity) error {
	if i.Valid() != nil {
		return errors.New("installation identity unavailable")
	}
	tag, err := db.Exec(ctx, `UPDATE installation_identity SET mode=$2,central_endpoint=$3,credential=$4,enrolled=$5 WHERE singleton=true AND installation_id=$1`, i.ID, i.Mode, i.Endpoint, i.Credential, i.Enrolled)
	if err != nil || tag.RowsAffected() != 1 {
		return errors.New("installation settings unavailable")
	}
	return nil
}

// ResetClone is an explicit offline operator operation. Product rows are untouched.
func ResetClone(ctx context.Context, db *pgxpool.Pool) (Identity, error) {
	i, err := New()
	if err != nil {
		return i, err
	}
	tag, err := db.Exec(ctx, `UPDATE installation_identity SET installation_id=$1,pseudonym_key=$2,enrollment_seed=$3,mode='local_only',central_endpoint='',credential='',enrolled=false,last_accepted_at=NULL WHERE singleton=true`, i.ID, i.Key, i.Seed)
	if err == nil && tag.RowsAffected() != 1 {
		err = errors.New("installation identity unavailable")
	}
	return i, err
}

func Confirm(ctx context.Context, db *pgxpool.Pool, i Identity, at time.Time) error {
	_, err := db.Exec(ctx, `UPDATE installation_identity SET last_accepted_at=$3 WHERE singleton=true AND installation_id=$1 AND credential=$2 AND mode='central'`, i.ID, i.Credential, at)
	return err
}
