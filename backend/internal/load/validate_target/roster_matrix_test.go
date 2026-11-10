package validate_target

import (
	"fmt"
	"testing"

	"github.com/google/uuid"
)

func TestRosterMatrixAcceptsIndependentAccountAndRoomCounts(t *testing.T) {
	for _, count := range []int{1, 10, 25, 50, 100} {
		for _, rooms := range []int{0, 1, 5, 20} {
			m := valid()
			m.Accounts, m.Voice = nil, nil
			for i := 0; i < count; i++ {
				m.Accounts = append(m.Accounts, Account{Login: fmt.Sprintf("qa_load_%03d", i), Password: "private", ID: uuid.NewString()})
			}
			for i := 0; i < rooms; i++ {
				m.Voice = append(m.Voice, uuid.NewString())
			}
			if err := m.ValidateRosterMatrix(); err != nil {
				t.Fatalf("accounts=%d rooms=%d: %v", count, rooms, err)
			}
		}
	}
}

func TestRosterMatrixRetainsSafetyChecks(t *testing.T) {
	for _, mutate := range []func(*Manifest){
		func(m *Manifest) { m.Origin = "https://foreign.invalid" },
		func(m *Manifest) { m.Guard = "http://10.0.0.1:4890" },
		func(m *Manifest) { m.Dataset = "production" },
		func(m *Manifest) { m.Accounts[0].Login = "realuser" },
		func(m *Manifest) { m.Voice = make([]string, 21) },
	} {
		m := valid()
		mutate(&m)
		if m.ValidateRosterMatrix() == nil {
			t.Fatal("accepted unsafe roster load target")
		}
	}
}
