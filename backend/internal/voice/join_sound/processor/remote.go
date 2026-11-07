package soundprocessor

import (
	"bytes"
	"context"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"time"
	s "voice-platform/backend/internal/voice/join_sound"
)

type Remote struct {
	endpoint string
	client   *http.Client
}

func NewRemote(endpoint string) (*Remote, error) {
	u, err := url.Parse(endpoint)
	if err != nil {
		return nil, s.ErrUnavailable
	}
	ip := net.ParseIP(u.Hostname())
	if u.Scheme != "http" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Path != "/normalize" || (u.Host != "join-sound-processor:8090" && (ip == nil || !ip.IsLoopback())) {
		return nil, s.ErrUnavailable
	}
	return &Remote{endpoint, &http.Client{Timeout: 10 * time.Second, Transport: &http.Transport{Proxy: nil, MaxIdleConnsPerHost: 2, ResponseHeaderTimeout: 9 * time.Second}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}}, nil
}
func (r *Remote) Process(ctx context.Context, raw []byte) (s.Audio, error) {
	if len(raw) == 0 || len(raw) > s.MaxInput {
		return s.Audio{}, s.ErrInvalid
	}
	req, err := http.NewRequestWithContext(ctx, "POST", r.endpoint, bytes.NewReader(raw))
	if err != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	res, err := r.client.Do(req)
	if err != nil {
		return s.Audio{}, s.ErrUnavailable
	}
	defer res.Body.Close()
	if res.StatusCode == 400 || res.StatusCode == 413 {
		return s.Audio{}, s.ErrInvalid
	}
	if res.StatusCode != 200 || res.Header.Get("Content-Type") != "audio/mpeg" {
		return s.Audio{}, s.ErrUnavailable
	}
	duration, err := strconv.Atoi(res.Header.Get("X-Audio-Duration-Ms"))
	if err != nil || duration < 300 || duration > 3000 {
		return s.Audio{}, s.ErrUnavailable
	}
	data, err := io.ReadAll(io.LimitReader(res.Body, s.MaxOutput+1))
	if err != nil || len(data) == 0 || len(data) > s.MaxOutput {
		return s.Audio{}, s.ErrUnavailable
	}
	return s.Audio{Bytes: data, DurationMS: duration}, nil
}
