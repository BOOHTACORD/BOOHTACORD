package clientupdates

const maxCatalogBytes = 256 * 1024

type Catalog struct {
	SchemaVersion     int     `json:"schema_version"`
	Revision          int     `json:"catalog_revision"`
	ApplicationFamily string  `json:"application_family"`
	Entries           []Entry `json:"entries"`
}

type Selector struct {
	Platform     string `json:"platform"`
	Distribution string `json:"distribution"`
	Channel      string `json:"channel"`
	Arch         string `json:"arch"`
}

type Entry struct {
	Selector
	State  string  `json:"state"`
	Target *Target `json:"target"`
}

type Target struct {
	InstallArtifact *InstallArtifact `json:"install_artifact,omitempty"`
	ReleaseID       string           `json:"release_id"`
	ReleaseOrder    int              `json:"release_order"`
	Version         string           `json:"version"`
	NativeBuild     *string          `json:"native_build"`
	Priority        string           `json:"priority"`
	PublishedAt     string           `json:"published_at"`
	ExpiresAt       string           `json:"expires_at,omitempty"`
	Summary         string           `json:"summary"`
	ReleaseNotesURL *string          `json:"release_notes_url"`
	Requirements    Requirements     `json:"requirements"`
	Action          Action           `json:"action"`
}

type Requirements struct {
	MinOSVersion  string   `json:"min_os_version,omitempty"`
	MinAndroidSDK int      `json:"min_android_sdk,omitempty"`
	SupportedArch []string `json:"supported_arches"`
}

type Action struct {
	Kind string  `json:"kind"`
	URL  *string `json:"url"`
}

type Policy struct {
	ApplicationFamily string `json:"application_family"`
	CatalogRevision   int    `json:"catalog_revision"`
	Selector
	State  string  `json:"state"`
	Target *Target `json:"target"`
}
