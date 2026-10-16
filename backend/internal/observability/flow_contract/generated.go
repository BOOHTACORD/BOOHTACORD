// Code generated from telemetry-flow-v1.json; DO NOT EDIT.
package flowcontract

const Version = 1
const MaxSpans = 32
const MaxAttributes = 32
const MaxEvents = 8
const MaxLinks = 8
const MaxLinkAttributes = 8
const MaxFlowDurationSeconds = 120
const MaxBatchBytes = 262144
const MaxSpanNameBytes = 64
const MaxAttributeKeyBytes = 128
const MaxAttributeStringBytes = 512

var Operations = map[string]bool{
	"api.request":             true,
	"startup":                 true,
	"session.restore":         true,
	"auth.login":              true,
	"message.send":            true,
	"message.render":          true,
	"voice.join":              true,
	"voice.leave":             true,
	"voice.reconnect":         true,
	"realtime.connect":        true,
	"realtime.reconnect":      true,
	"realtime.process":        true,
	"screen.share.start":      true,
	"screen.share.stop":       true,
	"screen.view":             true,
	"media.sample":            true,
	"audio.input.switch":      true,
	"desktop.update":          true,
	"voice.audio.sample":      true,
	"voice.volume.preference": true,
	"voice.disconnect":        true,
	"telemetry.export.health": true,
}

var Fields = map[string]Field{
	"app.schema.version":                    {Kind: "integer", Owner: "contract", Required: true, Min: 1, Max: 1, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"session.id":                            {Kind: "id", Owner: "server", Required: true, Min: 0, Max: 0, MinLength: 32, MaxLength: 32, Pattern: "^[0-9a-f]{32}$", Values: []string{}},
	"app.visit.id":                          {Kind: "id", Owner: "client", Required: true, Min: 0, Max: 0, MinLength: 32, MaxLength: 32, Pattern: "^[0-9a-f]{32}$", Values: []string{}},
	"app.flow.id":                           {Kind: "id", Owner: "client", Required: true, Min: 0, Max: 0, MinLength: 32, MaxLength: 32, Pattern: "^[0-9a-f]{32}$", Values: []string{}},
	"app.media.session.id":                  {Kind: "id", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 32, MaxLength: 32, Pattern: "^[0-9a-f]{32}$", Values: []string{}},
	"app.flow.name":                         {Kind: "enum", Owner: "client", Required: true, Min: 0, Max: 0, MinLength: 1, MaxLength: 18, Pattern: "", Values: []string{"startup", "session.restore", "auth.login", "message.send", "message.render", "voice.join", "voice.leave", "voice.reconnect", "realtime.connect", "realtime.reconnect", "realtime.process", "screen.share.start", "screen.share.stop", "screen.view", "telemetry.export"}},
	"app.flow.stage":                        {Kind: "enum", Owner: "observer", Required: true, Min: 0, Max: 0, MinLength: 1, MaxLength: 12, Pattern: "", Values: []string{"intent", "storage", "restore", "authenticate", "workspace", "request", "ack", "render", "lease", "credential", "connect", "microphone", "ready", "select", "subscribe", "track", "decoded", "first_frame", "publish", "stop", "refresh", "dispatch", "enqueue", "dependency", "commit", "authorize", "export"}},
	"app.flow.record":                       {Kind: "enum", Owner: "observer", Required: true, Min: 0, Max: 0, MinLength: 1, MaxLength: 10, Pattern: "", Values: []string{"start", "checkpoint", "terminal"}},
	"app.flow.outcome":                      {Kind: "enum", Owner: "observer", Required: true, Min: 0, Max: 0, MinLength: 1, MaxLength: 10, Pattern: "", Values: []string{"unknown", "success", "failed", "cancelled", "rejected", "timeout", "superseded"}},
	"app.flow.reason":                       {Kind: "enum", Owner: "observer", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 18, Pattern: "", Values: []string{"none", "permission_denied", "network", "dependency", "invalid", "conflict", "deadline", "disposed", "generation_changed", "revoked", "unsupported", "export_lost"}},
	"app.flow.attempt":                      {Kind: "integer", Owner: "client", Required: true, Min: 1, Max: 20, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.provenance":                        {Kind: "enum", Owner: "server", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 16, Pattern: "", Values: []string{"client_observed", "server_confirmed", "sfu_observed"}},
	"app.client.version":                    {Kind: "version", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 32, Pattern: "^[a-zA-Z0-9][a-zA-Z0-9.+_-]{0,31}$", Values: []string{}},
	"app.sample.age_ms":                     {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.sample.window_ms":                  {Kind: "number", Owner: "client", Required: false, Min: 1, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.capture_fps":                 {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 240, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.encoded_fps":                 {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 240, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.decoded_fps":                 {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 240, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.presented_fps":               {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 240, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.bitrate_bps":                 {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 100000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.rtt_ms":                      {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.jitter_ms":                   {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.loss_percent":                {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 100, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.direction":                   {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 8, Pattern: "", Values: []string{"sender", "receiver"}},
	"app.media.source":                      {Kind: "enum", Owner: "server", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 12, Pattern: "", Values: []string{"webrtc", "presentation", "sfu"}},
	"app.media.target_fps":                  {Kind: "number", Owner: "client", Required: false, Min: 1, Max: 240, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.sample_state":                {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 11, Pattern: "", Values: []string{"fresh", "stale", "unsupported", "unknown"}},
	"http.request.method":                   {Kind: "enum", Owner: "observer", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 7, Pattern: "", Values: []string{"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "OTHER"}},
	"http.response.status_code":             {Kind: "integer", Owner: "observer", Required: false, Min: 100, Max: 599, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.storage.result":                    {Kind: "enum", Owner: "server", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 9, Pattern: "", Values: []string{"committed", "replayed", "rejected"}},
	"app.media.adaptation_reason":           {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 9, Pattern: "", Values: []string{"none", "cpu", "bandwidth", "other"}},
	"app.cause.truncated":                   {Kind: "integer", Owner: "observer", Required: false, Min: 0, Max: 1000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.voice.mode":                        {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 22, Pattern: "", Values: []string{"participant", "listener", "microphone_unavailable"}},
	"app.export.queued":                     {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 128, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.export.accepted":                   {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 1000000000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.export.rejected":                   {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 1000000000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.export.dropped":                    {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 1000000000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.export.retried":                    {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 1000000000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.export.age_ms":                     {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 86400000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.total_bitrate_kbps":          {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 100000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.selected_layer_bitrate_kbps": {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 100000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.retransmitted_bitrate_kbps":  {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 100000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.encode_ms_per_frame":         {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.decode_ms_per_frame":         {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.jitter_buffer_ms_per_frame":  {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 60000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.nack_per_second":             {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 1000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.pli_per_second":              {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 1000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.fir_per_second":              {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 1000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.first_frame_ms":              {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 86400000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.freeze_duration_ms":          {Kind: "number", Owner: "client", Required: false, Min: 0, Max: 86400000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.stats_window_ms":             {Kind: "number", Owner: "client", Required: false, Min: 0.000001, Max: 10000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.freeze_count":                {Kind: "integer", Owner: "client", Required: false, Min: 0, Max: 1000000000, MinLength: 0, MaxLength: 0, Pattern: "", Values: []string{}},
	"app.media.collection_state":            {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 13, Pattern: "", Values: []string{"active", "inactive", "sdk_paused", "hidden", "reconnecting", "unavailable", "stale", "unknown", "no_subscriber"}},
	"app.media.presentation_source":         {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 11, Pattern: "", Values: []string{"web_rvfc", "unsupported"}},
	"app.media.stats_source":                {Kind: "enum", Owner: "client", Required: false, Min: 0, Max: 0, MinLength: 1, MaxLength: 15, Pattern: "", Values: []string{"webrtc_interval", "unsupported"}},
}
