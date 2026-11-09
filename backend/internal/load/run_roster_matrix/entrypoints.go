package runrostermatrix

import (
	"context"
	"voice-platform/backend/internal/load/validate_target"
)

func Run(parent context.Context, manifest validate_target.Manifest, mode string) Report {
	return RunWithSource(parent, manifest, mode, false)
}
func RunWithSource(parent context.Context, manifest validate_target.Manifest, mode string, sameSource bool) Report {
	return RunWithOptions(parent, manifest, mode, sameSource, false)
}
func RunWithOptions(parent context.Context, manifest validate_target.Manifest, mode string, sameSource, maintenanceChange bool) Report {
	return RunWithWorkload(parent, manifest, mode, sameSource, maintenanceChange, 0)
}
func RunWithWorkload(parent context.Context, manifest validate_target.Manifest, mode string, sameSource, maintenanceChange bool, messages int) Report {
	return RunWithWarmup(parent, manifest, mode, sameSource, maintenanceChange, messages, 0)
}
