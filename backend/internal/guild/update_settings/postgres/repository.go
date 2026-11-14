package guildsettingspostgres

import (
	"context"
	"github.com/jackc/pgx/v5"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
)

const selectSettings = `SELECT name,revision,welcome_channel_id::text,afk_channel_id::text,afk_timeout_seconds FROM guild_settings WHERE singleton=TRUE`

// Use the topology lock before the singleton lock in all three mutations:
// guild settings, registration welcome, and channel archive.
const TopologyLock int64 = 441903817

type Database interface {
	Begin(context.Context) (pgx.Tx, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database} }
func (r Repository) Read(ctx context.Context) (guildsettings.Settings, error) {
	var result guildsettings.Settings
	err := r.database.QueryRow(ctx, selectSettings).Scan(&result.Name, &result.Revision, &result.WelcomeChannelID, &result.AFKChannelID, &result.AFKTimeoutSeconds)
	return result, err
}
func (r Repository) Update(ctx context.Context, input guildsettings.Input) (guildsettings.Result, error) {
	tx, err := r.database.Begin(ctx)
	if err != nil {
		return guildsettings.Result{}, err
	}
	defer tx.Rollback(context.WithoutCancel(ctx))
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock($1)", TopologyLock); err != nil {
		return guildsettings.Result{}, err
	}
	var current guildsettings.Settings
	if err = tx.QueryRow(ctx, selectSettings+" FOR UPDATE").Scan(&current.Name, &current.Revision, &current.WelcomeChannelID, &current.AFKChannelID, &current.AFKTimeoutSeconds); err != nil {
		return guildsettings.Result{}, err
	}
	if current.Revision != input.ExpectedRevision {
		return guildsettings.Result{}, guildsettings.ErrConflict
	}
	changed := []string{}
	if input.SetName {
		current.Name = input.Name
		changed = append(changed, "name")
	}
	if input.SetWelcome {
		if input.WelcomeChannelID != "" {
			var active bool
			err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM channels WHERE id=$1::uuid AND kind='TEXT' AND archived_at IS NULL)`, input.WelcomeChannelID).Scan(&active)
			if err != nil {
				return guildsettings.Result{}, err
			}
			if !active {
				return guildsettings.Result{}, guildsettings.ErrChannel
			}
			current.WelcomeChannelID = &input.WelcomeChannelID
		} else {
			current.WelcomeChannelID = nil
		}
		changed = append(changed, "welcome_channel_id")
	}
	if input.SetAFK {
		if input.AFKChannelID != "" {
			var active bool
			err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM channels WHERE id=$1::uuid AND kind='VOICE' AND archived_at IS NULL AND admission_closed_at IS NULL)`, input.AFKChannelID).Scan(&active)
			if err != nil {
				return guildsettings.Result{}, err
			}
			if !active {
				return guildsettings.Result{}, guildsettings.ErrChannel
			}
			current.AFKChannelID = &input.AFKChannelID
			current.AFKTimeoutSeconds = input.AFKTimeoutSeconds
		} else {
			current.AFKChannelID = nil
			current.AFKTimeoutSeconds = 0
		}
		changed = append(changed, "afk_channel_id", "afk_timeout_seconds")
	}
	current.Revision++
	_, err = tx.Exec(ctx, `UPDATE guild_settings SET name=$1,revision=$2,welcome_channel_id=$3::uuid,afk_channel_id=$4::uuid,afk_timeout_seconds=$5,updated_at=now() WHERE singleton=TRUE`, current.Name, current.Revision, current.WelcomeChannelID, current.AFKChannelID, current.AFKTimeoutSeconds)
	if err != nil {
		return guildsettings.Result{}, err
	}
	for _, field := range changed {
		kind := "GUILD_NAME_UPDATED"
		if field == "welcome_channel_id" {
			kind = "GUILD_WELCOME_SETTINGS_UPDATED"
		} else if field == "afk_channel_id" || field == "afk_timeout_seconds" {
			kind = "GUILD_AFK_SETTINGS_UPDATED"
		}
		_, err = tx.Exec(ctx, `INSERT INTO audit_events(actor_user_id,event_type,metadata) VALUES($1::uuid,$2,jsonb_build_object('revision',$3::bigint,'changed_fields',jsonb_build_array($4::text)))`, input.ActorID, kind, current.Revision, field)
		if err != nil {
			return guildsettings.Result{}, err
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return guildsettings.Result{}, err
	}
	return guildsettings.Result{Settings: current, ChangedFields: changed}, nil
}
