package clientupdates

import (
	"fmt"
	"regexp"
	"time"
	"unicode/utf8"
)

var releaseIDPattern = regexp.MustCompile(`^[A-Za-z0-9._-]{1,96}$`)

func (catalog Catalog) validate(allowedHosts []string) error {
	if catalog.SchemaVersion != 1 || catalog.Revision < 1 {
		return fmt.Errorf("invalid catalog version or revision")
	}
	if catalog.ApplicationFamily != "boohtacord" {
		return fmt.Errorf("invalid application family")
	}
	if len(catalog.Entries) > 64 {
		return fmt.Errorf("catalog has more than 64 entries")
	}
	seen := map[Selector]bool{}
	for index, entry := range catalog.Entries {
		if err := entry.Selector.Validate(); err != nil {
			return fmt.Errorf("entry %d: %w", index, err)
		}
		if seen[entry.Selector] {
			return fmt.Errorf("entry %d duplicates selector", index)
		}
		seen[entry.Selector] = true
		if err := entry.validate(allowedHosts); err != nil {
			return fmt.Errorf("entry %d: %w", index, err)
		}
	}
	return nil
}

func (entry Entry) validate(allowedHosts []string) error {
	if entry.State != "published" && entry.State != "unconfigured" && entry.State != "disabled" {
		return fmt.Errorf("invalid state")
	}
	if entry.State != "published" {
		if entry.Target != nil {
			return fmt.Errorf("non-published entry has target")
		}
		return nil
	}
	if entry.Target == nil {
		return fmt.Errorf("published entry has no target")
	}
	if err := entry.Target.validate(allowedHosts, entry.Platform); err != nil {
		return err
	}
	return validateInstallArtifact(entry.Target.InstallArtifact, entry.Selector, *entry.Target)
}

func (target Target) validate(allowedHosts []string, platform string) error {
	if !releaseIDPattern.MatchString(target.ReleaseID) || target.ReleaseOrder < 1 {
		return fmt.Errorf("invalid release identity")
	}
	if len(target.Version) > 64 || target.NativeBuild != nil && len(*target.NativeBuild) > 64 || utf8.RuneCountInString(target.Summary) > 1000 {
		return fmt.Errorf("target text exceeds bounds")
	}
	if platform == "web" && target.NativeBuild != nil {
		return fmt.Errorf("web target has native build")
	}
	if platform != "web" && (target.NativeBuild == nil || *target.NativeBuild == "") {
		return fmt.Errorf("native target has no package build")
	}
	if target.Priority != "normal" && target.Priority != "important" {
		return fmt.Errorf("invalid priority")
	}
	if _, err := time.Parse(time.RFC3339, target.PublishedAt); err != nil {
		return fmt.Errorf("invalid published_at")
	}
	if target.ExpiresAt != "" {
		if _, err := time.Parse(time.RFC3339, target.ExpiresAt); err != nil {
			return fmt.Errorf("invalid expires_at")
		}
	}
	if len(target.Requirements.SupportedArch) == 0 {
		return fmt.Errorf("supported_arches is required")
	}
	for _, arch := range target.Requirements.SupportedArch {
		if !validArch[arch] {
			return fmt.Errorf("invalid supported architecture")
		}
	}
	if !validAction[target.Action.Kind] {
		return fmt.Errorf("invalid action")
	}
	if target.ReleaseNotesURL != nil {
		if err := validateURL(*target.ReleaseNotesURL, allowedHosts); err != nil {
			return fmt.Errorf("release notes: %w", err)
		}
	}
	if target.Action.URL == nil {
		if target.Action.Kind != "reload" {
			return fmt.Errorf("action URL is required")
		}
	} else if err := validateURL(*target.Action.URL, allowedHosts); err != nil {
		return fmt.Errorf("action: %w", err)
	}
	return nil
}
