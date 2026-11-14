package guildsettingsapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	guildsettings "voice-platform/backend/internal/guild/update_settings"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	guildlifecycle "voice-platform/backend/internal/observability/guild_lifecycle"
	tracehttp "voice-platform/backend/internal/observability/trace_http"
	requestid "voice-platform/backend/internal/security/request_id"
)

func (h Handler) Patch(w http.ResponseWriter, r *http.Request) {
	principal, ok := sessionapi.PrincipalFrom(r.Context())
	if !ok || principal.Role != "ADMINISTRATOR" {
		writeError(w, r, 403, "FORBIDDEN")
		return
	}
	ctx, span := h.Observer.StartSettings(r.Context())
	details := guildlifecycle.Details{UserID: principal.AccountID, UserName: principal.DisplayName, SessionDigest: principal.SessionDigest}
	var body struct {
		Name       json.RawMessage `json:"name"`
		Welcome    json.RawMessage `json:"welcome_channel_id"`
		AFKChannel json.RawMessage `json:"afk_channel_id"`
		AFKTimeout json.RawMessage `json:"afk_timeout_seconds"`
		Revision   int64           `json:"expected_revision"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10))
	decoder.DisallowUnknownFields()
	err := decoder.Decode(&body)
	if err == nil {
		var extra any
		if decoder.Decode(&extra) != io.EOF {
			err = guildsettings.ErrInvalid
		}
	}
	input := guildsettings.Input{ActorID: principal.AccountID, ExpectedRevision: body.Revision, SetName: body.Name != nil, SetWelcome: body.Welcome != nil, SetAFK: body.AFKChannel != nil || body.AFKTimeout != nil}
	tracehttp.SetGuildSettingsActions(r.Context(), input.SetName || (!input.SetWelcome && !input.SetAFK), input.SetWelcome, input.SetAFK)
	if err == nil && input.SetName {
		if string(body.Name) == "null" {
			err = guildsettings.ErrInvalid
		} else {
			err = json.Unmarshal(body.Name, &input.Name)
		}
	}
	if err == nil && input.SetWelcome && string(body.Welcome) != "null" {
		err = json.Unmarshal(body.Welcome, &input.WelcomeChannelID)
		if input.WelcomeChannelID == "" {
			err = guildsettings.ErrInvalid
		}
	}
	if err == nil && input.SetAFK {
		if body.AFKChannel == nil || body.AFKTimeout == nil || string(body.AFKTimeout) == "null" {
			err = guildsettings.ErrInvalid
		} else {
			if string(body.AFKChannel) != "null" {
				err = json.Unmarshal(body.AFKChannel, &input.AFKChannelID)
				if err == nil && input.AFKChannelID == "" {
					err = guildsettings.ErrInvalid
				}
			}
			if err == nil {
				err = json.Unmarshal(body.AFKTimeout, &input.AFKTimeoutSeconds)
			}
		}
	}
	details.Revision = body.Revision
	if input.SetName {
		details.ChangedFields = append(details.ChangedFields, "name")
	}
	if input.SetWelcome {
		details.ChangedFields = append(details.ChangedFields, "welcome_channel_id")
	}
	if input.SetAFK {
		details.ChangedFields = append(details.ChangedFields, "afk_channel_id", "afk_timeout_seconds")
	}
	if err == nil {
		input, err = guildsettings.Validate(input)
	}
	if err != nil {
		span.Finish("rejected", details)
		writeError(w, r, 400, "VALIDATION_FAILED")
		return
	}
	result, err := h.Store.Update(ctx, input)
	if err != nil {
		switch {
		case errors.Is(err, guildsettings.ErrConflict):
			span.Finish("conflict", details)
			writeError(w, r, 409, "CONFLICT")
		case errors.Is(err, guildsettings.ErrChannel):
			span.Finish("rejected", details)
			writeError(w, r, 400, "VALIDATION_FAILED")
		default:
			details.FailureStage = "database"
			span.Fail(err, details)
			writeError(w, r, 500, "INTERNAL")
		}
		return
	}
	details.Revision, details.ChangedFields, details.Committed = result.Revision, result.ChangedFields, true
	// A committed update stays successful if durable hint publication fails.
	err = h.publishUpdate(ctx, result.Revision)
	if err != nil {
		details.FailureStage = "realtime"
		span.Fail(err, details)
	} else {
		span.Finish("success", details)
	}
	writeJSON(w, 200, result.Settings)
}
func writeError(w http.ResponseWriter, r *http.Request, status int, code string) {
	writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": "Не удалось выполнить запрос настроек гильдии", "request_id": requestid.From(r.Context())}})
}
