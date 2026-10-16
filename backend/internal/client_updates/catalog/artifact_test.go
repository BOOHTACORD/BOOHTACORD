package clientupdates

import (
	"encoding/base64"
	"encoding/json"
	"testing"
)

func TestInstallArtifactBindsPublisherPayloadToPolicy(t *testing.T) {
	build := "78"
	target := Target{ReleaseID: "windows-78", ReleaseOrder: 78, Version: "1.0.43", NativeBuild: &build}
	selector := Selector{Platform: "windows", Distribution: "direct", Channel: "stable", Arch: "x64"}
	payload := map[string]any{"schema_version": 1, "application_family": "boohtacord", "package_id": "boohtacord_desktop", "release_id": target.ReleaseID, "release_order": 78, "version": target.Version, "native_build": build, "platform": "windows", "arch": "x64", "distribution": "direct", "channel": "stable", "package_type": "velopack_nupkg", "download_url": "https://github.com/Egkurilov/BOOHTACORD/releases/download/windows-v1.0.43/app-full.nupkg", "size": 1024, "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "min_os_version": "10.0", "min_api_version": 1, "min_updater_version": 1, "expires_at": "2027-01-01T00:00:00Z"}
	encode := func() *InstallArtifact {
		data, _ := json.Marshal(payload)
		return &InstallArtifact{SchemaVersion: 1, KeyID: "publisher", Payload: base64.StdEncoding.EncodeToString(data), Signature: base64.StdEncoding.EncodeToString(make([]byte, 64))}
	}
	if err := validateInstallArtifact(encode(), selector, target); err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{"release_id", "platform", "arch", "version", "native_build", "distribution", "package_type", "download_url"} {
		previous := payload[field]
		payload[field] = "mismatch"
		if err := validateInstallArtifact(encode(), selector, target); err == nil {
			t.Errorf("accepted mismatched %s", field)
		}
		payload[field] = previous
	}
	payload["size"] = int64(2_000_000_000)
	if err := validateInstallArtifact(encode(), selector, target); err == nil {
		t.Fatal("accepted oversized artifact")
	}
}
