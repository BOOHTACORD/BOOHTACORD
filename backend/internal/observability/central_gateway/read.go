package centralgateway

import (
	"context"
	"crypto/hmac"
	"io"
	"net/http"
	"strings"
	"time"
)

// Read access is owner-only. Per-installation provisioned datasources choose a
// registered tenant in the trusted URL; writer credentials never authorize reads.
func (g *Gateway) read(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" || !hmac.Equal([]byte(r.Header.Get("Authorization")), []byte("Bearer "+g.config.ReadToken)) {
		w.WriteHeader(401)
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/read/tempo/")
	id, path, ok := strings.Cut(rest, "/")
	if !ok || strings.Contains(path, "..") || (!strings.HasPrefix(path, "api/") && path != "ready") {
		w.WriteHeader(404)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if _, err := g.config.Registry.Get(ctx, id); err != nil {
		w.WriteHeader(404)
		return
	}
	req, err := http.NewRequestWithContext(ctx, "GET", strings.TrimRight(g.config.TempoQueryURL, "/")+"/"+path+"?"+r.URL.RawQuery, nil)
	if err != nil {
		w.WriteHeader(400)
		return
	}
	req.Header.Set("X-Scope-OrgID", id)
	response, err := g.config.Client.Do(req)
	if err != nil {
		w.WriteHeader(503)
		return
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 8*1024*1024+1))
	if err != nil || len(body) > 8*1024*1024 {
		w.WriteHeader(502)
		return
	}
	w.Header().Set("Content-Type", response.Header.Get("Content-Type"))
	w.WriteHeader(response.StatusCode)
	_, _ = w.Write(body)
}
