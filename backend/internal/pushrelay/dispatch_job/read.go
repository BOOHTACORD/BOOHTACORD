package dispatchjob

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	provider "voice-platform/backend/internal/pushrelay/fcm_provider"
)

func (s Store) read(ctx context.Context, tx pgx.Tx, j Job, now time.Time) (provider.Message, bool, error) {
	var m provider.Message
	var state, namespace string
	var token, public []byte
	var expires time.Time
	err := tx.QueryRow(ctx, `SELECT target_kind,platform,namespace,state,token_cipher,expires_at,public_key FROM relay_devices WHERE id=$1::uuid FOR SHARE`, j.DeviceID).Scan(&m.TargetKind, &m.Platform, &namespace, &state, &token, &expires, &public)
	if errors.Is(err, pgx.ErrNoRows) {
		return m, false, nil
	}
	if err != nil {
		return m, false, err
	}
	if s.Platforms != nil && !s.Platforms[m.Platform] {
		return m, false, nil
	}
	if namespace != s.Namespace || !expires.After(now) || s.Box == nil {
		return m, false, nil
	}
	if (j.Kind == "notification" && state != "active") || (j.Kind == "challenge" && state != "pending") {
		return m, false, nil
	}
	raw, err := s.Box.Open(token, enroll.DeviceScope(j.DeviceID, s.Namespace, m.TargetKind, m.Platform, public))
	if err != nil {
		return m, false, nil
	}
	m.Target = string(raw)
	for i := range raw {
		raw[i] = 0
	}
	m.Payload, err = s.Box.Open(j.Cipher, enroll.JobScope(j.ID, j.DeviceID, j.GrantID, j.Kind, s.Namespace, j.Reference))
	if err != nil {
		return m, false, nil
	}
	m.Kind = j.Kind
	m.ExpiresAt = j.ExpiresAt
	if j.Kind == "notification" {
		var binding string
		var generation int64
		var allowed bool
		err = tx.QueryRow(ctx, `SELECT binding_id::text,generation,state='active' AND expires_at>$2 FROM relay_grants WHERE id=$1::uuid AND device_id=$3::uuid FOR SHARE`, j.GrantID, now, j.DeviceID).Scan(&binding, &generation, &allowed)
		if errors.Is(err, pgx.ErrNoRows) {
			return m, false, nil
		}
		if err != nil {
			return m, false, err
		}
		var p delivery.Payload
		if !allowed || json.Unmarshal(m.Payload, &p) != nil || p.BindingRef != binding || p.Generation != generation {
			return m, false, nil
		}
	}
	if _, err = provider.Build(m, now); err != nil {
		return m, false, nil
	}
	return m, true, nil
}
