package runrostermatrix

import (
	"net/http"

	"voice-platform/backend/internal/load/validate_target"
)

func actorClient(index int, sameSource bool) *http.Client {
	if sameSource {
		return validate_target.ClientFrom(0)
	}
	return validate_target.ClientFrom(index + 1)
}
