package installationapi

import (
	"net/http"
	central "voice-platform/backend/internal/observability/central_export"
)

func Headers(next http.Handler, runtime *central.Runtime) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if runtime != nil {
			i := runtime.Identity()
			if i.Valid() == nil {
				w.Header().Set("X-Installation-ID", i.ID)
			}
		}
		next.ServeHTTP(w, r)
	})
}
