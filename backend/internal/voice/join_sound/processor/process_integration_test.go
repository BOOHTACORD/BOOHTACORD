//go:build soundprocessor

package soundprocessor

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"math"
	"os"
	"path/filepath"
	"testing"
	"time"
	s "voice-platform/backend/internal/voice/join_sound"
)

func wav(seconds float64) []byte {
	size := int(48000*seconds) * 2
	var b bytes.Buffer
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
func TestRealNormalizationAndAdversarialInputs(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	p := Processor{}
	for _, raw := range [][]byte{[]byte("<html>fake.mp3</html>"), wav(.2), wav(3.2)} {
		if _, err := p.Process(ctx, raw); !errors.Is(err, s.ErrInvalid) {
			t.Fatal("invalid audio accepted", err)
		}
	}
	for _, format := range []string{"wav", "mp3", "ogg"} {
		t.Run(format, func(t *testing.T) {
			raw := wav(2)
			if format != "wav" {
				input := filepath.Join(t.TempDir(), "input.wav")
				if err := os.WriteFile(input, raw, 0600); err != nil {
					t.Fatal(err)
				}
				var err error
				raw, _, err = command(ctx, "ffmpeg", "-nostdin", "-v", "error", "-i", input, "-f", format, "pipe:1")
				if err != nil {
					t.Fatal(err)
				}
			}
			got, err := p.Process(ctx, raw)
			if err != nil {
				t.Fatal(err)
			}
			if len(got.Bytes) > s.MaxOutput || got.DurationMS < 300 || got.DurationMS > 3000 || bytes.HasPrefix(got.Bytes, []byte("ID3")) {
				t.Fatal("unsafe normalized output")
			}
		})
	}
}
