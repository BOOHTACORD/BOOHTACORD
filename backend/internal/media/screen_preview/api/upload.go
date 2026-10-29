package screenpreviewapi

import (
	"net/http"

	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

func (handler *Handler) upload(writer http.ResponseWriter, request *http.Request) {
	writeFailure(writer, request, screenpreview.ErrServerManaged)
}
