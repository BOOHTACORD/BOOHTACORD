package matrixchat

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"io"
	"net/http"
	"voice-platform/backend/internal/load/validate_target"
)

// ReceiptError retains only the status, never the response body or request data.
type ReceiptError struct{ StatusCode int }

func (*ReceiptError) Error() string { return "synthetic message status rejected" }

// Send is used only after the runner has checked ownership of the fixture.
func Send(ctx context.Context, client *http.Client, origin, channel string) (string, error) {
	if client == nil || validate_target.Loopback(origin, true) != nil || uuid.Validate(channel) != nil {
		return "", errors.New("unsafe synthetic message target")
	}
	data, err := json.Marshal(map[string]string{"client_message_id": uuid.NewString(), "body": "synthetic load message"})
	if err != nil {
		return "", errors.New("invalid synthetic message")
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, origin+"/api/v1/channels/"+channel+"/messages", bytes.NewReader(data))
	if err != nil {
		return "", errors.New("invalid message request")
	}
	request.Header.Set("Origin", origin)
	request.Header.Set("Content-Type", "application/json")
	copy := *client
	copy.CheckRedirect = func(*http.Request, []*http.Request) error { return errors.New("fixture redirect refused") }
	response, err := copy.Do(request)
	if err != nil {
		return "", errors.New("synthetic message request failed")
	}
	defer response.Body.Close()
	var receipt struct {
		ID string `json:"id"`
	}
	if response.StatusCode != http.StatusCreated {
		return "", &ReceiptError{StatusCode: response.StatusCode}
	}
	if json.NewDecoder(io.LimitReader(response.Body, 4096)).Decode(&receipt) != nil || uuid.Validate(receipt.ID) != nil {
		return "", errors.New("invalid synthetic message receipt")
	}
	return receipt.ID, nil
}
