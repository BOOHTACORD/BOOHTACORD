package supportcontact

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"testing"
)

const actor = "11111111-1111-4111-8111-111111111111"
const peer = "22222222-2222-4222-8222-222222222222"

type fakeDB struct {
	account string
	active  bool
	err     error
	mode    string
	consent bool
}

func (d fakeDB) QueryRow(context.Context, string, ...any) pgx.Row { return d }
func (d fakeDB) Scan(values ...any) error {
	if d.err != nil {
		return d.err
	}
	*values[0].(*int64) = 3
	*values[1].(*string) = d.account
	*values[2].(*bool) = d.active
	*values[3].(*string) = d.mode
	*values[4].(*int) = 1
	*values[5].(*bool) = true
	*values[6].(*bool) = d.consent
	*values[7].(*string) = peer
	return nil
}
func TestProductSupportCarriesPublicNoticeAndPerUserConsent(t *testing.T) {
	got, err := New(fakeDB{account: peer, active: true, mode: "product"}).Resolve(context.Background(), actor)
	if err != nil || got.Mode != "product" || !got.RepositoryPublic || !got.ConsentRequired || got.NoticeVersion != 1 {
		t.Fatal("missing public consent metadata", err)
	}
	got, err = New(fakeDB{account: peer, active: true, mode: "product", consent: true}).Resolve(context.Background(), actor)
	if err != nil || got.ConsentRequired {
		t.Fatal("current consent was not recognized", err)
	}
}
func TestOnlyActiveServerAssignedOtherAccountCanBeSupport(t *testing.T) {
	for _, row := range []struct {
		name, account, actor, state, exposed string
		active                               bool
	}{
		{"unassigned", "", actor, "not_configured", "", false},
		{"blocked", peer, actor, "unavailable", "", false},
		{"self", peer, peer, "self", "", true},
		{"active", peer, actor, "available", peer, true},
	} {
		t.Run(row.name, func(t *testing.T) {
			got, err := New(fakeDB{account: row.account, active: row.active}).Resolve(context.Background(), row.actor)
			if err != nil || got.State != row.state || got.AccountID != row.exposed || got.Revision != 3 {
				t.Fatalf("unsafe support state: %+v %v", got, err)
			}
		})
	}
}
func TestMissingConfigurationFailsClosed(t *testing.T) {
	got, err := New(fakeDB{err: errors.New("private database detail")}).Resolve(context.Background(), actor)
	if err == nil || got.AccountID != "" {
		t.Fatal("untrusted support contact exposed")
	}
}
func TestAssignRejectsNonAccountInputBeforeSQL(t *testing.T) {
	for _, value := range []string{"Поддержка", "not-a-uuid", "https://public.example.test"} {
		if _, err := New(fakeDB{}).Assign(context.Background(), value); !errors.Is(err, ErrInvalid) {
			t.Fatal("assignment accepted non-account input")
		}
	}
}
