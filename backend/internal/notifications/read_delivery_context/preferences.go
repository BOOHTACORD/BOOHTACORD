package readdeliverycontext

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	p "voice-platform/backend/internal/notifications/preferences"
	access "voice-platform/backend/internal/notifications/preferences/access"
)

type Preferences struct {
	Settings  p.Settings
	Effective p.Preference
	UpdatedAt time.Time
}

func (r Reader) Preferences(ctx context.Context, account, kind, conversation string) (Preferences, error) {
	out := Preferences{Settings: p.Default()}
	var raw []byte
	err := r.database.QueryRow(ctx, `SELECT settings,COALESCE((SELECT max(changed_at) FROM notification_preference_fences WHERE account_id=$1::uuid AND(kind='ALL' OR kind=$2 OR(kind=$3 AND target=$4::uuid))),'-infinity'::timestamptz) FROM notification_preferences WHERE account_id=$1::uuid`, account, kind, map[string]string{"DM": "DIRECT_MESSAGE", "TEXT": "CHANNEL"}[kind], conversation).Scan(&raw, &out.UpdatedAt)
	if !errors.Is(err, pgx.ErrNoRows) {
		if err != nil {
			return out, err
		}
		if json.Unmarshal(raw, &out.Settings) != nil {
			return out, ErrUnavailable
		}
	}
	base := out.Settings.Text
	targetKind := "CHANNEL"
	if kind == "DM" {
		base = out.Settings.DM
		targetKind = "DIRECT_MESSAGE"
	}
	out.Effective = base
	for _, override := range out.Settings.Overrides {
		if override.Kind == targetKind && override.ID == conversation {
			out.Effective = override.Preference
			break
		}
	}
	// An active account/type pause remains stronger than a conversation all override.
	if base.PausedUntil != nil && (out.Effective.PausedUntil == nil || base.PausedUntil.After(*out.Effective.PausedUntil)) {
		out.Effective.PausedUntil = base.PausedUntil
	}
	return out, nil
}
func (r Reader) Allowed(ctx context.Context, account, kind, conversation string) (bool, error) {
	target := "CHANNEL"
	if kind == "DM" {
		target = "DIRECT_MESSAGE"
	} else if kind != "TEXT" {
		return false, nil
	}
	return access.New(r.database).Allowed(ctx, account, p.Override{Kind: target, ID: conversation})
}
func (r Reader) Read(ctx context.Context, account string, m Message) (bool, error) {
	query := `SELECT (message_created_at,message_id)>=($3::timestamptz,$4::uuid) FROM channel_read_cursors WHERE account_id=$1::uuid AND channel_id=$2::uuid`
	if m.Kind == "DM" {
		query = `SELECT (message_created_at,message_id)>=($3::timestamptz,$4::uuid) FROM direct_message_read_cursors WHERE account_id=$1::uuid AND direct_message_id=$2::uuid`
	}
	var read bool
	err := r.database.QueryRow(ctx, query, account, m.ConversationID, m.CreatedAt, m.ID).Scan(&read)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return read, err
}
