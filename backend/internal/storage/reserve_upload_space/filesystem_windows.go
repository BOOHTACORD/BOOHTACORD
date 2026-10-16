//go:build windows

package reserveuploadspace

import (
	"context"
	"fmt"
	"golang.org/x/sys/windows"
)

type Filesystem struct{ path string }

func NewFilesystem(path string) (Filesystem, error) {
	if path == "" {
		return Filesystem{}, ErrInvalidSpace
	}
	return Filesystem{path: path}, nil
}

func (filesystem Filesystem) Snapshot(ctx context.Context) (Snapshot, error) {
	if err := ctx.Err(); err != nil {
		return Snapshot{}, err
	}
	name, err := windows.UTF16PtrFromString(filesystem.path)
	if err != nil {
		return Snapshot{}, ErrInvalidSpace
	}
	var available, total, free uint64
	if err := windows.GetDiskFreeSpaceEx(name, &available, &total, &free); err != nil {
		return Snapshot{}, fmt.Errorf("measure attachment filesystem: %w", err)
	}
	const maximumInt64 = uint64(1<<63 - 1)
	if total == 0 || total > maximumInt64 || available > total {
		return Snapshot{}, ErrInvalidSpace
	}
	return Snapshot{AvailableBytes: int64(available), TotalBytes: int64(total)}, nil
}
