package soundprocessor

import (
	"context"
	"errors"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"
	s "voice-platform/backend/internal/voice/join_sound"
)

type worker struct {
	processor s.Processor
	slot      chan struct{}
}

func NewWorker(processor s.Processor) http.Handler { return &worker{processor, make(chan struct{}, 1)} }
func (w *worker) ServeHTTP(out http.ResponseWriter, r *http.Request) {
	out.Header().Set("Cache-Control", "no-store")
	out.Header().Set("X-Content-Type-Options", "nosniff")
	if r.Method != "POST" || r.URL.Path != "/normalize" {
		out.WriteHeader(404)
		return
	}
	select {
	case w.slot <- struct{}{}:
		defer func() { <-w.slot }()
	default:
		out.WriteHeader(429)
		return
	}
	raw, err := io.ReadAll(http.MaxBytesReader(out, r.Body, s.MaxInput))
	if err != nil {
		out.WriteHeader(413)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	audio, err := w.processor.Process(ctx, raw)
	if err != nil {
		for _, stage := range []string{"inspect", "streams", "format", "decode", "encode", "levels"} {
			if err.Error() == s.ErrInvalid.Error()+": "+stage {
				log.Printf("join_sound_rejected stage=%s", stage)
			}
		}
		if errors.Is(err, s.ErrInvalid) {
			out.WriteHeader(400)
		} else {
			out.WriteHeader(503)
		}
		return
	}
	if len(audio.Bytes) == 0 || len(audio.Bytes) > s.MaxOutput || audio.DurationMS < 300 || audio.DurationMS > 3000 {
		out.WriteHeader(503)
		return
	}
	out.Header().Set("Content-Type", "audio/mpeg")
	out.Header().Set("X-Audio-Duration-Ms", strconv.Itoa(audio.DurationMS))
	out.WriteHeader(200)
	_, _ = out.Write(audio.Bytes)
}
