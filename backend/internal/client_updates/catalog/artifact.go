package clientupdates

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// The server validates structure and recommendation binding. Only the installed
// client authenticates the publisher with its embedded, independent trust root.
type InstallArtifact struct {
	SchemaVersion int    `json:"schema_version"`
	KeyID         string `json:"key_id"`
	Payload       string `json:"payload"`
	Signature     string `json:"signature"`
}

type artifactPayload struct {
	SchemaVersion     int    `json:"schema_version"`
	ApplicationFamily string `json:"application_family"`
	PackageID         string `json:"package_id"`
	ReleaseID         string `json:"release_id"`
	ReleaseOrder      int    `json:"release_order"`
	Version           string `json:"version"`
	NativeBuild       string `json:"native_build"`
	Platform          string `json:"platform"`
	Arch              string `json:"arch"`
	Distribution      string `json:"distribution"`
	Channel           string `json:"channel"`
	PackageType       string `json:"package_type"`
	DownloadURL       string `json:"download_url"`
	Size              int64  `json:"size"`
	SHA256            string `json:"sha256"`
	MinOSVersion      string `json:"min_os_version"`
	MinAPIVersion     int    `json:"min_api_version"`
	MinUpdaterVersion int    `json:"min_updater_version"`
	ExpiresAt         string `json:"expires_at"`
	NativeSignature   string `json:"native_signature,omitempty"`
}

func validateInstallArtifact(envelope *InstallArtifact, selector Selector, target Target) error {
	if envelope == nil {
		return nil
	}
	reject := fmt.Errorf("invalid publisher install artifact")
	if envelope.SchemaVersion != 1 || !releaseIDPattern.MatchString(envelope.KeyID) || len(envelope.Payload) > 16384 {
		return reject
	}
	payload, err := base64.StdEncoding.Strict().DecodeString(envelope.Payload)
	if err != nil || len(payload) > 12288 {
		return reject
	}
	signature, err := base64.StdEncoding.Strict().DecodeString(envelope.Signature)
	if err != nil || len(signature) != 64 {
		return reject
	}
	var value artifactPayload
	decoder := json.NewDecoder(bytes.NewReader(payload))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&value) != nil || decoder.Decode(new(any)) != io.EOF {
		return reject
	}
	if value.SchemaVersion != 1 || value.ApplicationFamily != "boohtacord" || target.NativeBuild == nil ||
		value.ReleaseID != target.ReleaseID || value.ReleaseOrder != target.ReleaseOrder || value.Version != target.Version || value.NativeBuild != *target.NativeBuild ||
		value.Platform != selector.Platform || value.Distribution != selector.Distribution || value.Channel != selector.Channel ||
		(value.Arch != selector.Arch && value.Arch != "any") || value.Distribution != "direct" || value.Size < 1 || value.Size > 1024*1024*1024 ||
		!regexp.MustCompile(`^[0-9a-f]{64}$`).MatchString(value.SHA256) || value.MinAPIVersion != 1 || value.MinUpdaterVersion != 1 ||
		!regexp.MustCompile(`^\d+(\.\d+){0,3}$`).MatchString(value.MinOSVersion) {
		return reject
	}
	if _, err := time.Parse(time.RFC3339, value.ExpiresAt); err != nil {
		return reject
	}
	switch value.Platform {
	case "windows":
		if value.PackageType != "velopack_nupkg" || value.PackageID != "boohtacord_desktop" {
			return reject
		}
	case "macos":
		sig, err := base64.StdEncoding.Strict().DecodeString(value.NativeSignature)
		if err != nil || len(sig) != 64 || value.PackageType != "sparkle_zip" || value.PackageID != "ru.boohtacord.boohtacordDesktop" {
			return reject
		}
	default:
		return reject
	}
	u, err := url.Parse(value.DownloadURL)
	if err != nil || len(value.DownloadURL) > 2048 || u.Scheme != "https" || u.Host != "github.com" || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
		return reject
	}
	prefix := "/BOOHTACORD/BOOHTACORD/releases/download/"
	if !strings.HasPrefix(u.EscapedPath(), prefix) {
		return reject
	}
	parts := strings.Split(strings.TrimPrefix(u.EscapedPath(), prefix), "/")
	if len(parts) != 2 {
		return reject
	}
	for _, part := range parts {
		if !regexp.MustCompile(`^[A-Za-z0-9_][A-Za-z0-9._-]{0,190}$`).MatchString(part) {
			return reject
		}
	}
	return nil
}
