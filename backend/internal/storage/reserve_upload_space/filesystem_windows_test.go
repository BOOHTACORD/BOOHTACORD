//go:build windows

package reserveuploadspace

import (
	"context"
	"errors"
	"testing"
)

func TestWindowsFilesystemReportsActualBoundedSpace(t *testing.T) {
	filesystem, err := NewFilesystem(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	snapshot, err := filesystem.Snapshot(context.Background())
	if err != nil || snapshot.TotalBytes <= 0 || snapshot.AvailableBytes < 0 || snapshot.AvailableBytes > snapshot.TotalBytes {
		t.Fatalf("invalid measured space: %#v, error %v", snapshot, err)
	}
}

func TestWindowsFilesystemRejectsInvalidPathAndCancelledContext(t *testing.T) {
	if _, err := NewFilesystem(""); !errors.Is(err, ErrInvalidSpace) {
		t.Fatalf("empty path: %v", err)
	}
	filesystem, err := NewFilesystem(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := filesystem.Snapshot(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancelled snapshot: %v", err)
	}
	invalid, err := NewFilesystem("invalid\x00path")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := invalid.Snapshot(context.Background()); err == nil {
		t.Fatal("invalid native path accepted")
	}
}
