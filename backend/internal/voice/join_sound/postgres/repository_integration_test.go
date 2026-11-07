package soundstore_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	fixture "voice-platform/backend/internal/testsupport/postgres"
	s "voice-platform/backend/internal/voice/join_sound"
	db "voice-platform/backend/internal/voice/join_sound/postgres"
)

func TestPrivateSoundRequiresSameRoomAndLiveSession(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	const owner = "11111111-1111-4111-8111-111111111111"
	const viewer = "22222222-2222-4222-8222-222222222222"
	const category = "33333333-3333-4333-8333-333333333333"
	const channel = "44444444-4444-4444-8444-444444444444"
	var digest [32]byte
	digest[0] = 1
	for _, v := range []struct{ id, login string }{{owner, "sound_owner"}, {viewer, "sound_viewer"}} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,$2,'test','MEMBER')`, v.id, v.login); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := pool.Exec(ctx, `INSERT INTO categories(id,name,position) VALUES($1,'qa',0)`, category); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO channels(id,category_id,name,kind,position) VALUES($1,$2,'qa','VOICE',0)`, channel, category); err != nil {
		t.Fatal(err)
	}
	var ownerDigest [32]byte
	ownerDigest[0] = 2
	for _, v := range []struct {
		id     string
		digest [32]byte
	}{{owner, ownerDigest}, {viewer, digest}} {
		if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, v.digest[:], v.id); err != nil {
			t.Fatal(err)
		}
	}
	repo := db.New(pool)
	revision, err := repo.Reserve(ctx, owner)
	if err != nil || revision != 0 {
		t.Fatal("initial reserve", err)
	}
	if _, err = repo.Reserve(ctx, owner); !errors.Is(err, s.ErrRateLimited) {
		t.Fatal("upload throttle", err)
	}
	sound, err := repo.Replace(ctx, s.Actor{Account: owner, SessionDigest: ownerDigest}, revision, s.Audio{Bytes: []byte{1}, DurationMS: 1000})
	if err != nil {
		t.Fatal(err)
	}
	sound, err = repo.Enable(ctx, s.Actor{Account: owner, SessionDigest: ownerDigest}, true)
	if err != nil {
		t.Fatal(err)
	}
	actor := s.Actor{Account: viewer, SessionDigest: digest}
	if _, err = repo.Fetch(ctx, actor, sound.ID); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("nonmember access", err)
	}
	for _, v := range []struct {
		id     string
		digest [32]byte
	}{{owner, ownerDigest}, {viewer, digest}} {
		if _, err = pool.Exec(ctx, `INSERT INTO voice_leases(id,user_id,channel_id,session_token_digest) VALUES(gen_random_uuid(),$1,$2,$3)`, v.id, channel, v.digest[:]); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = repo.Fetch(ctx, actor, sound.ID); err != nil {
		t.Fatal("same room denied", err)
	}
	actor.SessionDigest[0] = 3
	if _, err = repo.Fetch(ctx, actor, sound.ID); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("different session access", err)
	}
	actor.SessionDigest = digest
	if _, err = pool.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE user_id=$1`, viewer); err != nil {
		t.Fatal(err)
	}
	if _, err = repo.Fetch(ctx, actor, sound.ID); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("revoked session access", err)
	}
	second, err := repo.Replace(ctx, s.Actor{Account: owner, SessionDigest: ownerDigest}, sound.Revision, s.Audio{Bytes: []byte{2}, DurationMS: 1000})
	if err != nil || second.ID == sound.ID {
		t.Fatal("replacement", err)
	}
	if _, err = repo.Fetch(ctx, s.Actor{Account: owner, SessionDigest: ownerDigest}, sound.ID); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("old sound retained", err)
	}
	verifyManagement(t, ctx, repo, s.Actor{Account: owner, SessionDigest: ownerDigest}, actor, second.ID)
	if _, err = pool.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE user_id=$1`, owner); err != nil {
		t.Fatal(err)
	}
	if _, err = repo.Replace(ctx, s.Actor{Account: owner, SessionDigest: ownerDigest}, second.Revision, s.Audio{Bytes: []byte{1}, DurationMS: 1000}); !errors.Is(err, s.ErrNotFound) {
		t.Fatal("revoked upload completion", err)
	}
}
