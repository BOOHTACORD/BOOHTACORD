//go:build !linux && !windows

package reserveuploadspace

import "context"

type Filesystem struct{}

func NewFilesystem(string) (Filesystem, error) { return Filesystem{}, ErrInvalidSpace }

func (Filesystem) Snapshot(context.Context) (Snapshot, error) {
	return Snapshot{}, ErrInvalidSpace
}
