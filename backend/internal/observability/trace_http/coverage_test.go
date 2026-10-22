package tracehttp

import (
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCurrentProductMutationsAndSearchHaveBoundedApplicationEvents(t *testing.T) {
	routes := map[string]string{
		"PUT /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}":                 "app.message.reaction.added",
		"DELETE /api/v1/channels/{channelID}/messages/{messageID}/reactions/{emoji}":              "app.message.reaction.removed",
		"PUT /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}":    "app.dm.message.reaction.added",
		"DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}/reactions/{emoji}": "app.dm.message.reaction.removed",
		"PUT /api/v1/admin/text-channels/{channelID}/pins/{messageID}":                            "app.message.pinned",
		"DELETE /api/v1/admin/text-channels/{channelID}/pins/{messageID}":                         "app.message.unpinned",
		"GET /api/v1/search/messages":                                   "app.message.search.completed",
		"GET /api/v1/channels/{channelID}/search":                       "app.channel.search.completed",
		"GET /api/v1/direct-messages/{directMessageID}/search":          "app.dm.search.completed",
		"GET /api/v1/archives/text-channels/{channelID}/search":         "app.archive.search.completed",
		"POST /api/v1/admin/text-channels/{channelID}/readonly-archive": "app.channel.readonly_archive.created",
		"POST /api/v1/admin/archives/text-channels/{channelID}/restore": "app.channel.readonly_archive.restored",
		"PUT /api/v1/admin/accounts/{accountID}/voice-timeout":          "app.admin.voice.timeout.applied",
		"DELETE /api/v1/admin/accounts/{accountID}/voice-timeout":       "app.admin.voice.timeout.removed",
	}
	for route, want := range routes {
		t.Run(route, func(t *testing.T) {
			recorder := tracetest.NewSpanRecorder()
			provider := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(recorder))
			defer provider.Shutdown(t.Context())
			mux := http.NewServeMux()
			mux.HandleFunc(route, func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) })
			method, path, _ := strings.Cut(route, " ")
			for _, key := range []string{"channelID", "messageID", "directMessageID", "emoji", "accountID"} {
				path = strings.ReplaceAll(path, "{"+key+"}", "private")
			}
			Middleware(provider.Tracer("test"), mux, mux).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(method, path+"?query=secret", strings.NewReader("secret body")))
			spans := recorder.Ended()
			if len(spans) != 1 || len(spans[0].Events()) != 1 || spans[0].Events()[0].Name != want || len(spans[0].Events()[0].Attributes) != 0 {
				t.Fatalf("missing bounded event %s", want)
			}
		})
	}
}
