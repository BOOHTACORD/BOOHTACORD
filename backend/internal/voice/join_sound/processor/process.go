package soundprocessor

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	s "voice-platform/backend/internal/voice/join_sound"
)

type Processor struct{}

func (Processor) Process(ctx context.Context, raw []byte) (s.Audio, error) {
	if len(raw) == 0 || len(raw) > s.MaxInput {
		return s.Audio{}, s.ErrInvalid
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	dir, err := os.MkdirTemp("", "join-sound-")
	if err != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	defer os.RemoveAll(dir)
	input := filepath.Join(dir, "input")
	if os.WriteFile(input, raw, 0600) != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	info, _, err := command(ctx, "ffprobe", "-v", "error", "-protocol_whitelist", "file,pipe", "-show_entries", "format=format_name:stream=codec_type", "-of", "json", input)
	if err != nil {
		return s.Audio{}, fmt.Errorf("%w: inspect", s.ErrInvalid)
	}
	var metadata struct {
		Format struct {
			Name string `json:"format_name"`
		}
		Streams []struct {
			Kind string `json:"codec_type"`
		}
	}
	if json.Unmarshal(info, &metadata) != nil || len(metadata.Streams) != 1 || metadata.Streams[0].Kind != "audio" {
		return s.Audio{}, fmt.Errorf("%w: streams", s.ErrInvalid)
	}
	if metadata.Format.Name != "mp3" && metadata.Format.Name != "wav" && metadata.Format.Name != "ogg" {
		return s.Audio{}, fmt.Errorf("%w: format", s.ErrInvalid)
	}
	pcm, _, err := command(ctx, "ffmpeg", "-nostdin", "-v", "error", "-threads", "1", "-protocol_whitelist", "file,pipe", "-i", input, "-map", "0:a:0", "-t", "3.01", "-ac", "1", "-ar", "48000", "-f", "s16le", "pipe:1")
	duration := len(pcm) * 1000 / 96000
	if err != nil || len(pcm)%2 != 0 || duration < 300 || duration > 3000 {
		return s.Audio{}, fmt.Errorf("%w: decode", s.ErrInvalid)
	}
	samples := filepath.Join(dir, "pcm")
	if os.WriteFile(samples, pcm, 0600) != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	encoded, _, err := command(ctx, "ffmpeg", "-nostdin", "-v", "error", "-threads", "1", "-f", "s16le", "-ar", "48000", "-ac", "1", "-i", samples, "-t", "2.9", "-af", "loudnorm=I=-18:TP=-4:LRA=7", "-ar", "48000", "-ac", "1", "-map_metadata", "-1", "-write_id3v1", "0", "-id3v2_version", "0", "-c:a", "libmp3lame", "-b:a", "64k", "-f", "mp3", "pipe:1")
	if err != nil || len(encoded) == 0 || len(encoded) > s.MaxOutput {
		return s.Audio{}, fmt.Errorf("%w: encode", s.ErrInvalid)
	}
	output := filepath.Join(dir, "output.mp3")
	if os.WriteFile(output, encoded, 0600) != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	_, levels, err := command(ctx, "ffmpeg", "-nostdin", "-hide_banner", "-threads", "1", "-protocol_whitelist", "file,pipe", "-i", output, "-af", "loudnorm=I=-18:TP=-3:LRA=7:print_format=json", "-f", "null", "-")
	if err != nil || !safeLevels(levels) {
		return s.Audio{}, fmt.Errorf("%w: levels", s.ErrInvalid)
	}
	return s.Audio{Bytes: encoded, DurationMS: duration}, nil
}
func safeLevels(raw []byte) bool {
	start := strings.LastIndex(string(raw), "{")
	if start < 0 {
		return false
	}
	end := strings.Index(string(raw[start:]), "}")
	if end < 0 {
		return false
	}
	var levels struct {
		Peak     string `json:"input_tp"`
		Loudness string `json:"input_i"`
	}
	if json.Unmarshal(raw[start:start+end+1], &levels) != nil {
		return false
	}
	peak, err := strconv.ParseFloat(levels.Peak, 64)
	if err != nil || math.IsNaN(peak) || peak > -3 {
		return false
	}
	loudness, err := strconv.ParseFloat(levels.Loudness, 64)
	return err == nil && !math.IsNaN(loudness) && loudness <= -16
}
