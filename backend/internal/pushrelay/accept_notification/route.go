package acceptnotification

import (
	"bytes"
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
)

func destination(ctx context.Context, tx pgx.Tx, grant, tenant, namespace string, now time.Time) (route, error) {
	var r route
	err := tx.QueryRow(ctx, `SELECT g.device_id::text,g.binding_id::text,g.generation,d.platform,LEAST(g.expires_at,d.expires_at) FROM relay_grants g JOIN relay_tenants t ON t.id=g.tenant_id JOIN relay_devices d ON d.id=g.device_id
 WHERE g.id=$1::uuid AND g.tenant_id=$2::uuid AND t.namespace=$3 AND d.namespace=$3 AND g.state='active' AND d.state='active' AND g.expires_at>$4 AND d.expires_at>$4 FOR SHARE OF g,d`, grant, tenant, namespace, now).Scan(&r.Device, &r.Binding, &r.Generation, &r.Platform, &r.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return r, ErrRouteUnavailable
	}
	return r, err
}
func existing(ctx context.Context, tx pgx.Tx, in Input, hash []byte) (Status, bool, error) {
	var out Status
	var stored []byte
	err := tx.QueryRow(ctx, `SELECT job_ref::text,state,expires_at,request_hash FROM relay_jobs WHERE grant_id=$1::uuid AND job_ref=$2::uuid`, in.GrantID, in.Payload.NotificationRef).Scan(&out.JobRef, &out.State, &out.ExpiresAt, &stored)
	if errors.Is(err, pgx.ErrNoRows) {
		return out, false, nil
	}
	if err != nil {
		return out, false, err
	}
	if !bytes.Equal(stored, hash) {
		return out, true, ErrConflict
	}
	out.Version = 1
	if out.State == "pending" || out.State == "retry" || out.State == "claimed" {
		out.State = "accepted_by_relay"
	}
	return out, true, nil
}
