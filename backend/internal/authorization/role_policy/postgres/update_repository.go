package rolepolicypostgres

import (
	"context"
	"encoding/json"
	"fmt"

	permissionregistry "voice-platform/backend/internal/authorization/permission_registry"
	rolepolicy "voice-platform/backend/internal/authorization/role_policy"
)

const selectMemberForUpdate = selectMemberPolicy + " FOR UPDATE"

const updateMemberPolicy = `
UPDATE role_permissions SET
 text_create=$1, text_delete=$2, voice_create=$3, voice_delete=$4,
 category_create=$5, category_delete=$6, revision=revision+1,
 updated_at=now(), updated_by=$7
WHERE role='MEMBER'
RETURNING text_create, text_delete, voice_create, voice_delete,
 category_create, category_delete, revision`

const auditMemberPolicy = `
INSERT INTO audit_events (actor_user_id, event_type, metadata)
VALUES ($1, 'MEMBER_PERMISSIONS_UPDATED',
 jsonb_build_object('before', $2::jsonb, 'after', $3::jsonb, 'revision', $4::bigint))`

func (repository Repository) UpdateMember(ctx context.Context, command rolepolicy.UpdateCommand) (permissionregistry.Policy, error) {
	transaction, err := repository.database.Begin(ctx)
	if err != nil {
		return permissionregistry.Policy{}, fmt.Errorf("begin role policy update: %w", err)
	}
	committed := false
	defer func() {
		if !committed {
			_ = transaction.Rollback(ctx)
		}
	}()
	current, err := loadPolicy(ctx, transaction, selectMemberForUpdate, "MEMBER")
	if err != nil {
		return permissionregistry.Policy{}, err
	}
	if current.Revision != command.ExpectedRevision {
		return permissionregistry.Policy{}, rolepolicy.ErrRevisionConflict
	}
	if command.Policy.AddsDeleteGrant(current) && !command.ConfirmDeleteGrants {
		return permissionregistry.Policy{}, rolepolicy.ErrDeleteGrantConfirmationRequired
	}
	if command.Policy.SameValues(current) {
		if err := transaction.Commit(ctx); err != nil {
			return permissionregistry.Policy{}, err
		}
		committed = true
		return current, nil
	}
	next, err := updatePolicy(ctx, transaction, command)
	if err != nil {
		return permissionregistry.Policy{}, err
	}
	beforeJSON, _ := json.Marshal(current.Values())
	afterJSON, _ := json.Marshal(next.Values())
	if err := transaction.Exec(ctx, auditMemberPolicy, command.ActorID, beforeJSON, afterJSON, next.Revision); err != nil {
		return permissionregistry.Policy{}, fmt.Errorf("audit role policy: %w", err)
	}
	if err := transaction.Commit(ctx); err != nil {
		return permissionregistry.Policy{}, fmt.Errorf("commit role policy: %w", err)
	}
	committed = true
	return next, nil
}

func updatePolicy(ctx context.Context, transaction Transaction, command rolepolicy.UpdateCommand) (permissionregistry.Policy, error) {
	p := command.Policy
	return loadPolicy(ctx, transaction, updateMemberPolicy, p.TextCreate, p.TextDelete, p.VoiceCreate, p.VoiceDelete, p.CategoryCreate, p.CategoryDelete, command.ActorID)
}

func loadPolicy(ctx context.Context, source interface {
	QueryRow(context.Context, string, ...any) Row
}, statement string, arguments ...any) (permissionregistry.Policy, error) {
	var p permissionregistry.Policy
	err := source.QueryRow(ctx, statement, arguments...).Scan(&p.TextCreate, &p.TextDelete, &p.VoiceCreate, &p.VoiceDelete, &p.CategoryCreate, &p.CategoryDelete, &p.Revision)
	if err != nil {
		return p, fmt.Errorf("read role policy: %w", err)
	}
	return p, nil
}
