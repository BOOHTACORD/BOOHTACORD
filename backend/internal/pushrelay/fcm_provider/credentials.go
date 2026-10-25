package fcmprovider

import (
	"context"
	"encoding/json"
	"errors"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"io"
	"net/http"
	"os"
	"regexp"
	"time"
)

var ErrConfiguration = errors.New("relay provider unavailable")

type httpClient interface {
	Do(*http.Request) (*http.Response, error)
}
type Sender struct {
	client  httpClient
	tokens  oauth2.TokenSource
	project string
}

var projectPattern = regexp.MustCompile(`^[a-z][a-z0-9-]{4,61}[a-z0-9]$`)

// Only the dedicated publisher process loads this service-account file.
// Self-hosted guild servers receive no Firebase or APNs credential.
func New(path, project string) (*Sender, error) {
	if !projectPattern.MatchString(project) {
		return nil, ErrConfiguration
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, ErrConfiguration
	}
	defer file.Close()
	raw, err := io.ReadAll(io.LimitReader(file, 65537))
	if err != nil || len(raw) > 65536 {
		return nil, ErrConfiguration
	}
	var identity struct {
		Type    string `json:"type"`
		Project string `json:"project_id"`
	}
	if json.Unmarshal(raw, &identity) != nil || identity.Type != "service_account" || identity.Project != project {
		return nil, ErrConfiguration
	}
	configuration, err := google.JWTConfigFromJSON(raw, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil || configuration.Email == "" || len(configuration.PrivateKey) == 0 {
		return nil, ErrConfiguration
	}
	configuration.TokenURL = "https://oauth2.googleapis.com/token"
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = nil
	client := &http.Client{Transport: transport, Timeout: 5 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	tokenClient := &http.Client{Transport: transport, Timeout: 2 * time.Second, CheckRedirect: client.CheckRedirect}
	ctx := context.WithValue(context.Background(), oauth2.HTTPClient, tokenClient)
	return &Sender{client: client, tokens: oauth2.ReuseTokenSource(nil, configuration.TokenSource(ctx)), project: project}, nil
}
