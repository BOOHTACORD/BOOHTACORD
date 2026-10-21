package ownsessionpostgres

import (
	"crypto/sha256"
	"encoding/json"
	"github.com/google/uuid"
	"strings"
	"testing"
	guildfixture "voice-platform/backend/internal/testsupport/guild_lifecycle"
)

func TestReadOnlyCallerSessionsWithSafeDTO(t *testing.T) {
	f := guildfixture.New(t)
	other := uuid.NewString()
	_, err := f.Pool.Exec(f.Context, `INSERT INTO users(id,login,display_name,password_hash,role)
        VALUES($1,'foreign-member','Member','fixture','MEMBER')`, other)
	if err != nil {
		t.Fatal(err)
	}
	current := sha256.Sum256([]byte("own-current"))
	second := sha256.Sum256([]byte("own-other"))
	foreign := sha256.Sum256([]byte("foreign-session"))
	for _, row := range []struct {
		owner  string
		digest [32]byte
	}{
		{f.Admin, current}, {f.Admin, second}, {other, foreign},
	} {
		_, err = f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest) VALUES($1,$2)`, row.owner, row.digest[:])
		if err != nil {
			t.Fatal(err)
		}
	}
	expired := sha256.Sum256([]byte("expired-session"))
	idle := sha256.Sum256([]byte("idle-session"))
	if _, err = f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest,expires_at) VALUES($1,$2,now()-interval '1 second')`, f.Admin, expired[:]); err != nil {
		t.Fatal("insert expired session:", err)
	}
	if _, err = f.Pool.Exec(f.Context, `INSERT INTO sessions(user_id,token_digest,last_active_at) VALUES($1,$2,now()-interval '31 days')`, f.Admin, idle[:]); err != nil {
		t.Fatal("insert idle session:", err)
	}
	page, err := New(f.Pool).Read(f.Context, f.Admin, current, "")
	if err != nil || len(page.Sessions) != 2 {
		t.Fatal("caller session boundary failed", err)
	}
	marked := 0
	for _, item := range page.Sessions {
		if item.Current {
			marked++
		}
		if _, err := uuid.Parse(item.ID); err != nil {
			t.Fatal("invalid public session handle")
		}
	}
	if marked != 1 {
		t.Fatal("current session must be marked once")
	}
	encoded, err := json.Marshal(page)
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{"digest", "token", "ip_address", "fingerprint", "user_id"} {
		if strings.Contains(string(encoded), forbidden) {
			t.Fatal("unsafe session DTO field")
		}
	}
}
