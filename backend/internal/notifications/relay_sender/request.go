package relaysender

import (
	"bytes"
	"context"
	"encoding/json"
	"github.com/google/uuid"
	"io"
	"net/http"
	"net/http/httptrace"
	"sync/atomic"
	"time"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

type response struct {
	Code    int
	Error   string
	Status  accept.Status
	Written bool
}

func (s Sender) post(ctx context.Context, path, tenant string, body any) (response, error) {
	raw, err := json.Marshal(body)
	if err != nil {
		return response{}, ErrConfiguration
	}
	signed := signature.Request{Method: "POST", Path: path, Role: "tenant", Subject: tenant, Timestamp: time.Now().UTC().Truncate(time.Second).Format(time.RFC3339), Nonce: uuid.NewString(), Body: raw}
	signed.Signature, err = signature.Sign(s.config.InstallationPrivateKey, signed)
	if err != nil {
		return response{}, ErrConfiguration
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	request, err := http.NewRequestWithContext(ctx, "POST", s.config.Origin+path, bytes.NewReader(raw))
	if err != nil {
		return response{}, ErrConfiguration
	}
	request.Header.Set("Content-Type", "application/json")
	for name, value := range map[string]string{"X-Relay-Role": signed.Role, "X-Relay-Subject": signed.Subject, "X-Relay-Timestamp": signed.Timestamp, "X-Relay-Nonce": signed.Nonce, "X-Relay-Signature": signed.Signature} {
		request.Header.Set(name, value)
	}
	var wrote atomic.Bool
	request = request.WithContext(httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote.Store(true) }}))
	reply, err := s.client.Do(request)
	out := response{Written: wrote.Load()}
	if err != nil {
		return out, err
	}
	if reply == nil {
		return out, ErrConfiguration
	}
	out.Code = reply.StatusCode
	if reply.Body == nil {
		return out, nil
	}
	defer reply.Body.Close()
	data, err := io.ReadAll(io.LimitReader(reply.Body, 16385))
	if err != nil || len(data) > 16384 {
		return out, ErrConfiguration
	}
	if reply.StatusCode == 200 || reply.StatusCode == 202 {
		if json.Unmarshal(data, &out.Status) != nil {
			return out, ErrConfiguration
		}
	} else {
		var failure struct {
			Error struct {
				Code string `json:"code"`
			} `json:"error"`
		}
		if json.Unmarshal(data, &failure) == nil && len(failure.Error.Code) <= 64 {
			out.Error = failure.Error.Code
		}
	}
	return out, nil
}
