package validate_target

import (
	"errors"
	"github.com/google/uuid"
	"net"
	"net/url"
	"regexp"
	"strings"
)

type Account struct{ Login, Password, ID string }
type Manifest struct {
	Origin, Guard, Nonce, Dataset, Owner, Commit, Text, PrivateDM string
	Voice                                                         []string
	Accounts                                                      []Account
	UploadBytes, MaxRequests, MaxSeconds                          int
}

func Loopback(value string, secure bool) error {
	u, err := url.Parse(value)
	if err != nil || u.User != nil || u.RawQuery != "" || u.Fragment != "" || u.Path != "" || u.Port() == "" {
		return errors.New("target must be an exact loopback origin")
	}
	ip := net.ParseIP(u.Hostname())
	if u.Hostname() != "localhost" && (ip == nil || !ip.IsLoopback()) {
		return errors.New("target is not loopback")
	}
	if secure && u.Scheme != "https" || !secure && u.Scheme != "http" {
		return errors.New("invalid target scheme")
	}
	return nil
}

func (m Manifest) Validate() error {
	return m.validate(false)
}

// ValidateRosterMatrix admits empty rooms without relaxing target ownership checks.
func (m Manifest) ValidateRosterMatrix() error {
	return m.validate(true)
}

func (m Manifest) validate(rosterMatrix bool) error {
	if Loopback(m.Origin, true) != nil || Loopback(m.Guard, false) != nil {
		return errors.New("unsafe load target")
	}
	if m.Dataset != "qa" || !regexp.MustCompile(`^qa-client-[a-f0-9]{16}$`).MatchString(m.Owner) || len(m.Nonce) < 32 || !regexp.MustCompile(`^[a-f0-9]{40}$`).MatchString(m.Commit) {
		return errors.New("missing owned disposable dataset identity")
	}
	if m.MaxSeconds < 1 || m.MaxSeconds > 7200 || m.MaxRequests < 1 || m.MaxRequests > 1000000 || m.UploadBytes < 1 || m.UploadBytes > 25000000 {
		return errors.New("invalid bounded resource budget")
	}
	if len(m.Accounts) < 1 || len(m.Accounts) > 100 ||
		(!rosterMatrix && len(m.Voice) < (len(m.Accounts)+19)/20) ||
		(rosterMatrix && len(m.Voice) > 20) {
		return errors.New("voice profile exceeds 100 total or 20 per room")
	}
	seen := map[string]bool{}
	for _, a := range m.Accounts {
		if !strings.HasPrefix(a.Login, "qa_load_") || len(a.Password) < 1 || uuid.Validate(a.ID) != nil || seen[a.ID] {
			return errors.New("foreign or duplicate synthetic account")
		}
		seen[a.ID] = true
	}
	for _, id := range append(append([]string{}, m.Voice...), m.Text, m.PrivateDM) {
		if uuid.Validate(id) != nil || seen[id] {
			return errors.New("invalid or duplicate fixture resource")
		}
		seen[id] = true
	}
	return nil
}
