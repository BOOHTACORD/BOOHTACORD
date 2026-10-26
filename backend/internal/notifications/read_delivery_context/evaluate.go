package readdeliverycontext

import (
	"context"
	"time"
	policy "voice-platform/backend/internal/notifications/eligibility"
	d "voice-platform/backend/internal/notifications/register_device"
)

func (r Reader) Evaluate(ctx context.Context, account string, m Message, original []string, device d.Record, now time.Time, ttl time.Duration) (policy.Result, error) {
	deny := func(reason string) (policy.Result, error) { return policy.Result{Reason: reason}, nil }
	if device.State != "active" || !device.ExpiresAt.After(now) {
		return deny("revoked")
	}
	if device.ConsentAt.After(m.CreatedAt) {
		return deny("device_enabled")
	}
	prefs, err := r.Preferences(ctx, account, m.Kind, m.ConversationID)
	if err != nil {
		return policy.Result{}, err
	}
	if prefs.UpdatedAt.After(m.CreatedAt) {
		return deny("preference_changed")
	}
	// A pause applies to events created during it even if dispatch resumes later.
	if prefs.Effective.PausedUntil != nil && m.CreatedAt.Before(*prefs.Effective.PausedUntil) {
		return deny("paused")
	}
	allowed, err := r.Allowed(ctx, account, m.Kind, m.ConversationID)
	if err != nil {
		return policy.Result{}, err
	}
	read, err := r.Read(ctx, account, m)
	if err != nil {
		return policy.Result{}, err
	}
	pause := int64(0)
	if prefs.Effective.PausedUntil != nil && prefs.Effective.PausedUntil.After(now) {
		pause = prefs.Effective.PausedUntil.UnixMilli()
		if pause <= now.UnixMilli() {
			pause = now.UnixMilli() + 1
		}
	}
	return policy.Evaluate(policy.Input{TTLMS: ttl.Milliseconds(), Version: prefs.Settings.Version, Kind: m.Kind, ActorID: m.AuthorID, RecipientID: account, Mentioned: VerifiedMention(original, m.Mentions, account), Read: read, Deleted: m.Deleted, Archived: m.Archived, Revoked: !allowed || m.AuthorBlocked, OperatorAvailable: true, AccountEnabled: prefs.Settings.Enabled, DeviceConsent: true, Mode: string(prefs.Effective.Mode), PausedUntilMS: pause, NowMS: now.UnixMilli(), OccurredAtMS: m.CreatedAt.UnixMilli()}), nil
}
