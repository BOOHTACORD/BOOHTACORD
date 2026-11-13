package exercise_actor

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"time"
)

func (a *Actor) Message(ctx context.Context, receivers []*Actor, attachments []string) error {
	clientID := uuid.NewString()
	body := map[string]any{"client_message_id": clientID, "body": "synthetic load message"}
	if len(attachments) > 0 {
		body["attachment_ids"] = attachments
	}
	var message struct {
		ID string `json:"id"`
	}
	started := time.Now()
	if err := a.Request(ctx, "message", "POST", "/channels/"+a.Manifest.Text+"/messages", body, 201, &message); err != nil {
		return err
	}
	if uuid.Validate(message.ID) != nil {
		return errors.New("invalid message receipt")
	}
	releases := make([]func(), 0, len(receivers))
	defer func() {
		for _, release := range releases {
			release()
		}
	}()
	for _, receiver := range receivers {
		release, err := receiver.Socket.Track(message.ID)
		if err != nil {
			a.Results.Observe("fanout", 503, time.Since(started))
			return err
		}
		releases = append(releases, release)
	}
	for _, receiver := range receivers {
		elapsed, err := receiver.Socket.Wait(ctx, message.ID, started)
		status := 200
		if err != nil {
			status = 503
		}
		a.Results.Observe("fanout", status, elapsed)
		if err != nil {
			return err
		}
	}
	return a.Request(ctx, "cursor", "PUT", "/channels/"+a.Manifest.Text+"/read-cursor", map[string]string{"message_id": message.ID}, 200, nil)
}
func (a *Actor) ACL(ctx context.Context) error {
	if err := a.Request(ctx, "acl", "GET", "/admin/audit", nil, 403, nil); err != nil {
		return err
	}
	expected := 404
	if a.Account.ID == a.Manifest.Accounts[0].ID {
		expected = 200
	}
	if err := a.Request(ctx, "acl", "GET", "/direct-messages/"+a.Manifest.PrivateDM+"/messages", nil, expected, nil); err != nil {
		return err
	}
	return a.Request(ctx, "origin_acl", "POST", "/channels/"+a.Manifest.Text+"/messages", map[string]string{"client_message_id": uuid.NewString(), "body": "synthetic load message"}, 403, nil)
}
