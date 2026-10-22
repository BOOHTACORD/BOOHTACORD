// Package supportcontact resolves a local, ordinary second participant, never a privileged inbox.
package supportcontact

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrInvalid = errors.New("invalid support account")
var ErrUnavailable = errors.New("support account unavailable")

type Contact struct {
	State            string `json:"state"`
	Revision         int64  `json:"revision"`
	AccountID        string `json:"account_id,omitempty"`
	ProductAccountID string `json:"product_account_id,omitempty"`
	Mode             string `json:"mode,omitempty"`
	NoticeVersion    int    `json:"notice_version,omitempty"`
	RepositoryPublic bool   `json:"repository_public"`
	ConsentRequired  bool   `json:"consent_required"`
}
type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }
func (s Store) Resolve(ctx context.Context, actor string) (Contact, error) {
	var caller any
	if actor != "" {
		caller = actor
	}
	var revision int64
	var id string
	var active bool
	var mode string
	var notice int
	var public, consent bool
	var productAccount string
	err := s.database.QueryRow(ctx, `SELECT c.revision, COALESCE(c.support_account_id::text,''),
 c.support_account_id IS NOT NULL AND u.id IS NOT NULL AND u.blocked_at IS NULL,
 c.mode,p.notice_version,p.repository_public,
 EXISTS(SELECT 1 FROM support_public_consents WHERE user_id=$1::uuid AND notice_version=p.notice_version),p.account_id::text
 FROM support_contact_configuration c LEFT JOIN users u ON u.id=c.support_account_id
 CROSS JOIN support_product_identity p WHERE c.singleton=true`, caller).Scan(&revision, &id, &active, &mode, &notice, &public, &consent, &productAccount)
	if err != nil {
		return Contact{State: "unavailable"}, ErrUnavailable
	}
	result := Contact{State: "not_configured", Revision: revision, Mode: mode, NoticeVersion: notice, RepositoryPublic: public, ConsentRequired: mode == "product" && !consent, ProductAccountID: productAccount}
	if id == "" {
		return result, nil
	}
	if !active {
		result.State = "unavailable"
		return result, nil
	}
	if actor == id {
		result.State = "self"
		return result, nil
	}
	result.State = "available"
	result.AccountID = id
	return result, nil
}
func (s Store) Assign(ctx context.Context, account string) (int64, error) {
	var target any
	if account != "" {
		id, err := uuid.Parse(account)
		if err != nil || id.String() != account {
			return 0, ErrInvalid
		}
		target = account
	}
	var revision int64
	err := s.database.QueryRow(ctx, assignContact, target).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrUnavailable
	}
	if err != nil {
		return 0, ErrUnavailable
	}
	return revision, nil
}
