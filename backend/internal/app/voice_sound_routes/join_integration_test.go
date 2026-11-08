//go:build soundprocessor

package voicesoundroutes

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	"voice-platform/backend/internal/identity/session"
	origin "voice-platform/backend/internal/security/origin_check"
	fixture "voice-platform/backend/internal/testsupport/postgres"
	s "voice-platform/backend/internal/voice/join_sound"
	processor "voice-platform/backend/internal/voice/join_sound/processor"
)

func TestJoinSoundHTTPNormalizationAndPrivateLifecycle(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	const account = "11111111-1111-4111-8111-111111111111"
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'sound_http','QA','test','MEMBER')`, account); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, make([]byte, 32), account); err != nil {
		t.Fatal(err)
	}
	worker := httptest.NewServer(processor.NewWorker(processor.Processor{}))
	defer worker.Close()
	mux := http.NewServeMux()
	if err := RegisterJoinSounds(mux, pool, authStub{}, worker.URL+"/normalize"); err != nil {
		t.Fatal(err)
	}
	wrap, err := origin.New("https://voice.example.test")
	if err != nil {
		t.Fatal(err)
	}
	send := func(method, path string, body []byte, source string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(method, path, bytes.NewReader(body))
		r.Header.Set("Origin", source)
		r.Header.Set("X-Voice-Sound-Account", account)
		r.AddCookie(&http.Cookie{Name: session.CookieName, Value: "qa"})
		w := httptest.NewRecorder()
		wrap(mux).ServeHTTP(w, r)
		return w
	}
	raw := testWave()
	if w := send("POST", "/api/v1/me/join-sound", raw, "https://evil.example"); w.Code != 403 {
		t.Fatalf("origin=%d", w.Code)
	}
	w := send("POST", "/api/v1/me/join-sound", raw, "https://voice.example.test")
	if w.Code != 201 {
		t.Fatalf("upload=%d", w.Code)
	}
	var sound s.Sound
	if json.Unmarshal(w.Body.Bytes(), &sound) != nil || sound.ID == "" {
		t.Fatal("upload metadata")
	}
	w = send("GET", "/api/v1/voice/join-sounds/"+sound.ID, nil, "")
	if w.Code != 200 || w.Body.Len() == 0 || w.Header().Get("Content-Type") != "audio/mpeg" {
		t.Fatal("private download failed")
	}
	if w = send("PATCH", "/api/v1/me/join-sound", []byte(`{"enabled":false}`), "https://voice.example.test"); w.Code != 200 {
		t.Fatal("disable", w.Code)
	}
	if w = send("DELETE", "/api/v1/me/join-sound", nil, "https://voice.example.test"); w.Code != 204 {
		t.Fatal("delete", w.Code)
	}
	if w = send("GET", "/api/v1/voice/join-sounds/"+sound.ID, nil, ""); w.Code != 404 {
		t.Fatal("deleted audio retained", w.Code)
	}
}
func testWave() []byte {
	var b bytes.Buffer
	size := 96000
	b.WriteString("RIFF")
	binary.Write(&b, binary.LittleEndian, uint32(size+36))
	b.WriteString("WAVEfmt ")
	for _, v := range []any{uint32(16), uint16(1), uint16(1), uint32(48000), uint32(96000), uint16(2), uint16(16)} {
		binary.Write(&b, binary.LittleEndian, v)
	}
	b.WriteString("data")
	binary.Write(&b, binary.LittleEndian, uint32(size))
	for i := 0; i < size/2; i++ {
		binary.Write(&b, binary.LittleEndian, int16(math.Sin(float64(i)*2*math.Pi*440/48000)*32000))
	}
	return b.Bytes()
}
