package uploadrequest

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"
)

func proxyFixtureBackend(writer http.ResponseWriter, request *http.Request) {
	if request.URL.Path == "/api/qa-health" {
		writer.WriteHeader(200)
		return
	}
	upload := request.Method == http.MethodPost && (request.URL.Path == "/api/v1/channels/owned/attachments" || request.URL.Path == "/api/v1/direct-messages/owned/attachments")
	if upload {
		bounded, cleanup, err := WithLimits(writer, request, 300*time.Millisecond, 40*time.Millisecond)
		if err != nil {
			http.Error(writer, "NATIVE_DEADLINE_UNSUPPORTED", 500)
			return
		}
		request = bounded
		defer cleanup()
		defer request.Body.Close()
		_, err = io.Copy(io.Discard, request.Body)
		if err == nil {
			writer.WriteHeader(201)
			return
		}
		if !TimedOut(request.Context()) {
			http.Error(writer, "UNEXPECTED_READ_ERROR", 500)
			return
		}
	} else {
		_, _ = io.Copy(io.Discard, request.Body)
	}
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(http.StatusRequestTimeout)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": "UPLOAD_TIMEOUT", "message": strings.Repeat("timeout", 2)}})
}
