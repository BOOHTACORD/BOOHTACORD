package pairinstallation

import (
	"bytes"
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

func pin(ctx context.Context, tx pgx.Tx, in Input, now time.Time) (string, error) {
	var known string
	var pinned []byte
	err := tx.QueryRow(ctx, `SELECT id::text,public_key FROM relay_tenants WHERE origin=$1 AND installation_id=$2::uuid AND namespace=$3`, in.Origin, in.InstallationID, in.Namespace).Scan(&known, &pinned)
	if err == nil {
		if !bytes.Equal(pinned, key(in.InstallationPublicKey)) {
			return "", ErrConflict
		}
		return known, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	var count int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM relay_tenants`).Scan(&count); err != nil {
		return "", err
	}
	if count >= 1000 {
		return "", auth.ErrLimit
	}
	var id string
	var stored []byte
	err = tx.QueryRow(ctx, `INSERT INTO relay_tenants(id,origin,installation_id,public_key,namespace,created_at)VALUES($1::uuid,$2,$3::uuid,$4,$5,$6)
 ON CONFLICT(origin,installation_id,namespace)DO UPDATE SET public_key=relay_tenants.public_key RETURNING id::text,public_key`, uuid.NewString(), in.Origin, in.InstallationID, key(in.InstallationPublicKey), in.Namespace, now).Scan(&id, &stored)
	if err != nil {
		return "", err
	}
	if !bytes.Equal(stored, key(in.InstallationPublicKey)) {
		return "", ErrConflict
	}
	return id, nil
}
