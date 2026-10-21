package centralexport

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
	gateway "voice-platform/backend/internal/observability/central_gateway"
	projection "voice-platform/backend/internal/observability/central_projection"
	identity "voice-platform/backend/internal/observability/installation"
)

func Endpoint(raw string) error {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Hostname() == "" || u.User != nil || u.RawQuery != "" || u.Fragment != "" || (u.Path != "" && u.Path != "/") || net.ParseIP(u.Hostname()) != nil {
		return errors.New("central endpoint must be a public HTTPS origin")
	}
	return nil
}
func secureClient() *http.Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = nil
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(address)
		if err != nil {
			return nil, err
		}
		ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
		if err != nil {
			return nil, err
		}
		for _, ip := range ips {
			if !ip.IP.IsGlobalUnicast() || ip.IP.IsPrivate() || ip.IP.IsLoopback() || ip.IP.IsLinkLocalUnicast() {
				return nil, errors.New("central address is private")
			}
		}
		if len(ips) == 0 {
			return nil, errors.New("central address unavailable")
		}
		return (&net.Dialer{Timeout: 2 * time.Second}).DialContext(ctx, network, net.JoinHostPort(ips[0].IP.String(), port))
	}
	return &http.Client{Timeout: 3 * time.Second, Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
}
func (r *Runtime) Enable(ctx context.Context, endpoint string) error {
	r.configureMu.Lock()
	defer r.configureMu.Unlock()
	if Endpoint(endpoint) != nil {
		return errors.New("central endpoint must be a public HTTPS origin")
	}
	i := r.Identity()
	if i.Valid() != nil {
		return errors.New("installation identity unavailable")
	}
	e := gateway.NewEnrollment(i, time.Now())
	raw, _ := json.Marshal(e)
	req, err := http.NewRequestWithContext(ctx, "POST", strings.TrimRight(endpoint, "/")+"/v1/enroll", bytes.NewReader(raw))
	if err != nil {
		return errors.New("enrollment unavailable")
	}
	req.Header.Set("Content-Type", "application/json")
	response, err := r.client.Do(req)
	if err != nil {
		return errors.New("enrollment unavailable")
	}
	defer response.Body.Close()
	var result gateway.EnrollmentResponse
	decoder := json.NewDecoder(io.LimitReader(response.Body, 8192))
	if response.StatusCode != 200 || decoder.Decode(&result) != nil || result.InstallationID != i.ID || result.PolicyVersion != 1 || len(result.Credential) > 256 || !strings.HasPrefix(result.Credential, i.ID+".") {
		return errors.New("enrollment rejected")
	}
	i.Mode = "central"
	i.Enrolled = true
	i.Endpoint = strings.TrimRight(endpoint, "/")
	i.Credential = result.Credential
	if r.save != nil {
		if err := r.save(ctx, i); err != nil {
			return errors.New("cannot save enrollment")
		}
	}
	r.replace(i)
	return nil
}
func (r *Runtime) deliver(ctx context.Context, next item, i identity.Identity) int {
	if Endpoint(i.Endpoint) != nil || i.Mode != "central" || i.Credential == "" {
		return 0
	}
	for attempt := 0; attempt < 3; attempt++ {
		bounded, cancel := context.WithTimeout(ctx, 3*time.Second)
		req, err := http.NewRequestWithContext(bounded, "POST", i.Endpoint+"/v1/"+next.kind, bytes.NewReader(next.body))
		if err != nil {
			cancel()
			return 0
		}
		req.Header.Set("Content-Type", "application/x-protobuf")
		req.Header.Set("Authorization", "Bearer "+i.Credential)
		response, err := r.client.Do(req)
		status := 0
		if err == nil {
			status = response.StatusCode
			_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 65536))
			response.Body.Close()
		}
		cancel()
		if status == 200 || status == 401 || status == 400 || status == 403 {
			return status
		}
		if attempt < 2 {
			timer := time.NewTimer(time.Duration(250*(1<<attempt)+int(time.Now().UnixNano()%100)) * time.Millisecond)
			select {
			case <-ctx.Done():
				timer.Stop()
				return 0
			case <-timer.C:
			}
		}
	}
	return 0
}

// Transport tees already encoded OTLP into a private bounded projection. Existing
// local diagnostics are delivered only to resolved private/loopback destinations.
func (r *Runtime) Transport() *http.Client {
	local := privateCollectorTransport(net.DefaultResolver.LookupIPAddr)
	return &http.Client{Timeout: 3 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }, Transport: roundTripper(func(req *http.Request) (*http.Response, error) {
		raw, err := io.ReadAll(io.LimitReader(req.Body, projection.MaxBytes+1))
		if err != nil {
			return nil, err
		}
		req.Body.Close()
		if len(raw) > projection.MaxBytes {
			return nil, projection.ErrPolicy
		}
		i := r.Identity()
		kind := "traces"
		var body []byte
		if strings.HasSuffix(req.URL.Path, "/metrics") {
			kind = "metrics"
			body, err = projection.Metrics(raw, i)
		} else {
			body, err = projection.Traces(raw, i)
		}
		if err == nil {
			r.Enqueue(kind, body)
		}
		if req.URL.Hostname() == "boohtacord-local-export.invalid" {
			return &http.Response{StatusCode: http.StatusOK, Header: make(http.Header), Body: io.NopCloser(strings.NewReader("")), Request: req}, nil
		}
		if req.URL.User != nil || (req.URL.Scheme != "http" && req.URL.Scheme != "https") {
			return nil, errors.New("invalid local collector destination")
		}
		req.Body = io.NopCloser(bytes.NewReader(raw))
		return local.RoundTrip(req)
	})}
}

type roundTripper func(*http.Request) (*http.Response, error)

func (f roundTripper) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func (r *Runtime) notifyDisabled(ctx context.Context, i identity.Identity) {
	if Endpoint(i.Endpoint) != nil {
		return
	}
	bounded, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(bounded, "POST", i.Endpoint+"/v1/status", strings.NewReader(`{"mode":"disabled"}`))
	if err != nil {
		return
	}
	req.Header.Set("Authorization", "Bearer "+i.Credential)
	req.Header.Set("Content-Type", "application/json")
	response, err := r.client.Do(req)
	if err == nil {
		response.Body.Close()
	}
}
