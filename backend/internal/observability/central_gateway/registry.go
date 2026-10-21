package centralgateway

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
)

var ErrRegistry = errors.New("installation registration rejected")

type Record struct {
	Mode       string     `json:"mode"`
	ID         string     `json:"installation_id"`
	PublicKey  []byte     `json:"-"`
	Enabled    bool       `json:"enabled"`
	Epoch      int64      `json:"policy_epoch"`
	Registered time.Time  `json:"registered_at"`
	LastSeen   *time.Time `json:"last_seen"`
}
type Registry interface {
	Enroll(context.Context, string, []byte, string) (Record, error)
	Get(context.Context, string) (Record, error)
	Seen(context.Context, string) error
}
type Postgres struct{ DB *pgxpool.Pool }

// Schema belongs only to the private central registry, never product accounts.
func (p Postgres) Initialize(ctx context.Context) error {
	_, err := p.DB.Exec(ctx, `CREATE TABLE IF NOT EXISTS telemetry_installations(installation_id uuid PRIMARY KEY,public_key bytea NOT NULL CHECK(octet_length(public_key)=32),enabled boolean NOT NULL DEFAULT true,epoch bigint NOT NULL DEFAULT 1,registered_at timestamptz NOT NULL DEFAULT now(),last_seen timestamptz,export_mode text NOT NULL DEFAULT 'central'); CREATE TABLE IF NOT EXISTS telemetry_enrollment_nonces(installation_id uuid NOT NULL REFERENCES telemetry_installations(installation_id),nonce text NOT NULL,expires_at timestamptz NOT NULL,PRIMARY KEY(installation_id,nonce))`)
	return err
}
func (p Postgres) Enroll(ctx context.Context, id string, key []byte, nonce string) (Record, error) {
	tx, err := p.DB.Begin(ctx)
	if err != nil {
		return Record{}, ErrRegistry
	}
	defer tx.Rollback(ctx)
	// Serialize registration capacity and owner binding; bounded public requests.
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(3360001)`); err != nil {
		return Record{}, ErrRegistry
	}
	if _, err = tx.Exec(ctx, `INSERT INTO telemetry_installations(installation_id,public_key) SELECT $1,$2 WHERE (SELECT count(*) FROM telemetry_installations)<10000 ON CONFLICT DO NOTHING`, id, key); err != nil {
		return Record{}, ErrRegistry
	}
	if _, err = tx.Exec(ctx, `UPDATE telemetry_installations SET export_mode='central' WHERE installation_id=$1 AND public_key=$2 AND enabled`, id, key); err != nil {
		return Record{}, ErrRegistry
	}
	var r Record
	err = tx.QueryRow(ctx, `SELECT installation_id::text,public_key,enabled,epoch,registered_at,last_seen,export_mode FROM telemetry_installations WHERE installation_id=$1 AND public_key=$2 AND enabled FOR UPDATE`, id, key).Scan(&r.ID, &r.PublicKey, &r.Enabled, &r.Epoch, &r.Registered, &r.LastSeen, &r.Mode)
	if err != nil {
		return Record{}, ErrRegistry
	}
	if _, err = tx.Exec(ctx, `DELETE FROM telemetry_enrollment_nonces WHERE expires_at<now()`); err != nil {
		return Record{}, ErrRegistry
	}
	if _, err = tx.Exec(ctx, `INSERT INTO telemetry_enrollment_nonces VALUES($1,$2,now()+interval '3 minutes')`, id, nonce); err != nil {
		return Record{}, ErrRegistry
	}
	if err = tx.Commit(ctx); err != nil {
		return Record{}, ErrRegistry
	}
	return r, nil
}
func (p Postgres) Get(ctx context.Context, id string) (Record, error) {
	var r Record
	err := p.DB.QueryRow(ctx, `SELECT installation_id::text,public_key,enabled,epoch,registered_at,last_seen,export_mode FROM telemetry_installations WHERE installation_id=$1`, id).Scan(&r.ID, &r.PublicKey, &r.Enabled, &r.Epoch, &r.Registered, &r.LastSeen, &r.Mode)
	if err != nil {
		return r, ErrRegistry
	}
	return r, nil
}
func (p Postgres) Seen(ctx context.Context, id string) error {
	_, err := p.DB.Exec(ctx, `UPDATE telemetry_installations SET last_seen=now(),export_mode='central' WHERE installation_id=$1 AND enabled`, id)
	return err
}

func (p Postgres) SetMode(ctx context.Context, id, mode string) error {
	_, err := p.DB.Exec(ctx, `UPDATE telemetry_installations SET export_mode=$2 WHERE installation_id=$1 AND enabled`, id, mode)
	return err
}
func (p Postgres) List(ctx context.Context) ([]Record, error) {
	rows, err := p.DB.Query(ctx, `SELECT installation_id::text,enabled,registered_at,last_seen,export_mode FROM telemetry_installations ORDER BY installation_id LIMIT 10000`)
	if err != nil {
		return nil, ErrRegistry
	}
	defer rows.Close()
	out := []Record{}
	for rows.Next() {
		var r Record
		if rows.Scan(&r.ID, &r.Enabled, &r.Registered, &r.LastSeen, &r.Mode) != nil {
			return nil, ErrRegistry
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
