package migrate

import (
	"context"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestRunExecutesEmbeddedMigrations(t *testing.T) {
	executor := &fakeExecutor{}
	if err := Run(context.Background(), executor); err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	expected := [][]string{
		{"CREATE TABLE IF NOT EXISTS users"},
		{"CREATE TABLE IF NOT EXISTS sessions"},
		{"CREATE INDEX IF NOT EXISTS sessions_active_user_id_idx"},
		{"CREATE TABLE IF NOT EXISTS password_resets"},
		{"CREATE TABLE IF NOT EXISTS bootstrap_state"},
		{"CREATE TABLE IF NOT EXISTS audit_events"},
		{"CREATE TABLE IF NOT EXISTS channel_topology_state"},
		{"CREATE TABLE IF NOT EXISTS categories"},
		{"CREATE TABLE IF NOT EXISTS channels"},
		{"CREATE TABLE IF NOT EXISTS voice_leases"},
		{"CREATE UNIQUE INDEX IF NOT EXISTS voice_leases_active_user_id_idx"},
		{"CREATE INDEX IF NOT EXISTS voice_leases_active_channel_id_idx"},
		{"ADD COLUMN IF NOT EXISTS session_token_digest"},
		{"CREATE INDEX IF NOT EXISTS voice_leases_active_session_digest_idx"},
		{"VOLUNTARY_LEAVE"},
		{"CREATE TABLE IF NOT EXISTS messages", "revision INTEGER NOT NULL DEFAULT 1", "messages_body_or_deleted_marker"},
		{"CREATE TABLE IF NOT EXISTS direct_messages", "direct_messages_unique_pair"},
		{"CREATE TABLE IF NOT EXISTS direct_message_messages", "direct_message_messages_author_client_unique"},
		{"direct_message_messages_history_idx"},
		{"ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES direct_message_messages"},
		{"CREATE TABLE IF NOT EXISTS direct_message_read_cursors", "PRIMARY KEY (account_id, direct_message_id)"},
		{"ADD COLUMN IF NOT EXISTS search_vector", "direct_message_messages_search_idx"},
		{"CREATE TABLE IF NOT EXISTS attachments", "attachments_exactly_one_target", "storage_key UUID NOT NULL UNIQUE"},
		{"CREATE TABLE IF NOT EXISTS message_attachments", "PRIMARY KEY (message_id, attachment_id)", "attachment_id UUID NOT NULL UNIQUE", "position BETWEEN 0 AND 9"},
		{"UPDATE bootstrap_state", "administrator_id IS NULL", "COUNT(*)", "= 1", "INSERT INTO audit_events"},
		{"ADD COLUMN IF NOT EXISTS search_vector", "messages_search_idx", "WHERE deleted_at IS NULL"},
		{"CREATE INDEX IF NOT EXISTS attachments_unattached_cleanup_idx", "ON attachments (created_at, storage_key)", "WHERE state = 'UNATTACHED'"},
		{"CREATE TABLE IF NOT EXISTS voice_sfu_revocations", "lease_id UUID PRIMARY KEY", "completed_at TIMESTAMPTZ", "attempt_count INTEGER NOT NULL DEFAULT 0"},
		{"CREATE TABLE IF NOT EXISTS maintenance_admission", "singleton BOOLEAN PRIMARY KEY", "active BOOLEAN NOT NULL DEFAULT FALSE"},
		{"ADD COLUMN IF NOT EXISTS avatar_key", "^[0-9a-f]{64}$"},
		{"DELETING", "attachments_deleting_cleanup_idx", "attachments_state_timestamps"},
		{"CREATE TABLE IF NOT EXISTS direct_message_attachments", "attachment_id UUID NOT NULL UNIQUE", "position BETWEEN 0 AND 9"},
		{"CREATE TABLE IF NOT EXISTS channel_read_cursors", "PRIMARY KEY (account_id, channel_id)"},
		{"notification_claim_token UUID", "notification_emitted_at TIMESTAMPTZ", "voice_revocation_pending_notification_index"},
		{"ADD COLUMN IF NOT EXISTS mention_user_ids UUID[]", "messages_live_mentions_idx", "direct_message_messages_live_mentions_idx"},
		{"CREATE TABLE IF NOT EXISTS realtime_events", "boot_epoch UUID NOT NULL", "recipient_ids UUID[]", "realtime_events_epoch_sequence_idx"},
		{"hidden_cleanup_claim_token UUID", "hidden_cleanup_claimed_at TIMESTAMPTZ", "attachments_hidden_cleanup_claim_idx"},
		{"unattached_cleanup_attempts", "unattached_cleanup_retry_after", "attachments_unattached_cleanup_retry_state", "attachments_unattached_cleanup_retry_idx", "attachments_unattached_cleanup_turn_seq"},
		{"DROP CONSTRAINT IF EXISTS messages_body_or_deleted_marker", "char_length(body) BETWEEN 0 AND 8000", "DROP CONSTRAINT IF EXISTS direct_message_messages_body_or_deleted_marker"},
		{"CREATE TABLE IF NOT EXISTS role_permissions", "role = 'MEMBER'", "ON CONFLICT (role) DO NOTHING", "revision BIGINT NOT NULL"},
		{"CREATE TABLE IF NOT EXISTS topology_command_receipts", "PRIMARY KEY (actor_id, client_request_id)", "intent_hash", "response_status"},
		{"ADD COLUMN IF NOT EXISTS description", "channels_description_length"},
		{"CREATE TABLE IF NOT EXISTS user_daily_activity", "PRIMARY KEY (activity_day, user_id)", "CREATE TABLE IF NOT EXISTS user_activity_collection"},
		{"CREATE TABLE IF NOT EXISTS guild_settings", "welcome_channel_id UUID", "ON CONFLICT (singleton) DO NOTHING"},
		{"ADD COLUMN IF NOT EXISTS kind", "SYSTEM_WELCOME", "messages_one_welcome_per_account", "guard_system_welcome"},
		{"ADD COLUMN IF NOT EXISTS public_id", "last_active_at", "sessions_public_id_unique"},
		{"ALTER TABLE voice_sfu_revocations ADD COLUMN IF NOT EXISTS trace_cause", "ALTER TABLE realtime_events ADD COLUMN IF NOT EXISTS trace_cause", "voice_trace_cause_bounded", "event_trace_cause_bounded"},
		{"screen_profile_operation_revision BIGINT NOT NULL DEFAULT 0", "screen_profile_operation_hash BYTEA", "octet_length(screen_profile_operation_hash) = 32"},
		{"ADD COLUMN IF NOT EXISTS profile_revision BIGINT NOT NULL DEFAULT 1", "CHECK (profile_revision > 0)"},
		{"ADD COLUMN IF NOT EXISTS readonly_archive", "DEFAULT FALSE", "channels_readonly_archive_state", "kind='TEXT' AND archived_at IS NOT NULL"},
		{"CREATE TABLE IF NOT EXISTS voice_timeouts", "enforce_voice_timeout_on_lease", "voice_timeout_lease_guard", "ERRCODE='42501'"},
		{"CREATE TABLE IF NOT EXISTS text_message_reactions", "CREATE TABLE IF NOT EXISTS direct_message_reactions", "CREATE TABLE IF NOT EXISTS text_message_pins", "clear_text_message_social", "clear_direct_message_social"},
		{"ADD COLUMN IF NOT EXISTS expires_at", "180 days", "ALTER COLUMN expires_at SET NOT NULL"},
		{"installation_identity", "pg_advisory_xact_lock", "pseudonym_key", "enrollment_seed", "local_only"},
		{"CREATE TABLE IF NOT EXISTS support_contact_configuration", "support_account_id UUID REFERENCES users(id)", "revision BIGINT", "CHECK (singleton)", "ON CONFLICT (singleton) DO NOTHING"},
		{"support_product_identity", "support_public_consents", "support_public_outbox", "consent_product_support_message", "support_service_session_guard"},
		{"CREATE TABLE IF NOT EXISTS notification_preferences"},
		{"CREATE TABLE IF NOT EXISTS notification_devices"},
		{"CREATE TABLE IF NOT EXISTS notification_outbox"},
		{"CREATE OR REPLACE FUNCTION create_notification_intent", "CREATE OR REPLACE TRIGGER message_notification_intent"},
		{"CREATE TABLE IF NOT EXISTS notification_deliveries"},
		{"CREATE TABLE IF NOT EXISTS notification_attention"},
		{"CREATE TABLE IF NOT EXISTS notification_preference_fences", "fence_notification_preference_changes"},
		{"reclaim_deleted_notification_budget", "notification_deleted_delivery", "notification_deleted_intent"},
		{"protect_support_service_account", "TG_OP='DELETE'", "RETURN OLD", "RETURN NEW", "ERRCODE='42501'"},
	}
	if len(executor.statements) != len(expected) {
		t.Fatalf("migration count = %d", len(executor.statements))
	}
	for index, fragments := range expected {
		for _, fragment := range fragments {
			if !strings.Contains(executor.statements[index], fragment) {
				t.Fatalf("migration %d lacks %q", index+1, fragment)
			}
		}
	}
}

func TestVoiceLeaseSessionDigestMigrationIsRepeatable(t *testing.T) {
	statement, err := files.ReadFile("migrations/0013_add_voice_lease_session_digest.sql")
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	if !strings.Contains(string(statement), "ADD COLUMN IF NOT EXISTS session_token_digest") {
		t.Fatal("voice lease session digest migration must use ADD COLUMN IF NOT EXISTS")
	}
}

type fakeExecutor struct {
	statements []string
}

func (executor *fakeExecutor) Exec(_ context.Context, statement string, _ ...any) (pgconn.CommandTag, error) {
	executor.statements = append(executor.statements, statement)
	return pgconn.NewCommandTag("CREATE TABLE"), nil
}
