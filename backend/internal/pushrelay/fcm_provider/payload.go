package fcmprovider

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"strconv"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

var ErrInvalid = errors.New("invalid provider notification")

type Message struct {
	TargetKind, Target, Platform, Kind string
	Payload                            []byte
	ExpiresAt                          time.Time
}

func Build(in Message, now time.Time) ([]byte, error) {
	if len(in.Target) < 16 || len(in.Target) > 4096 || (in.TargetKind != "fcm_fid" && in.TargetKind != "fcm_token") || (in.Platform != "ios" && in.Platform != "android") || len(in.Payload) > 4096 {
		return nil, ErrInvalid
	}
	for _, c := range in.Target {
		if c < 33 || c > 126 {
			return nil, ErrInvalid
		}
	}
	ttl := int(in.ExpiresAt.Sub(now) / time.Second)
	if ttl < 1 || ttl > 3600 {
		return nil, ErrInvalid
	}
	body := ""
	binding := "challenge"
	group := ""
	dataKey := "boohtacord"
	switch in.Kind {
	case "notification":
		var p delivery.Payload
		if strict(in.Payload, &p) != nil || p.Validate(now) != nil || !p.ExpiresAt.Equal(in.ExpiresAt) {
			return nil, ErrInvalid
		}
		body = map[string]string{"direct_message": "Новое личное сообщение", "mention": "Новое упоминание", "activity": "Новая активность"}[p.Template]
		binding = p.BindingRef
		group = p.GroupRef
	case "challenge":
		var p enroll.Proof
		if strict(in.Payload, &p) != nil || !receipt.ID(p.ChallengeID) {
			return nil, ErrInvalid
		}
		nonce, err := base64.RawURLEncoding.Strict().DecodeString(p.Nonce)
		if err != nil || len(nonce) != 32 || ttl > 300 {
			return nil, ErrInvalid
		}
		body = "Подтвердите настройку уведомлений в приложении"
		group = p.ChallengeID
		dataKey = "relay_challenge"
	default:
		return nil, ErrInvalid
	}
	hash := sha256.Sum256([]byte(group))
	collapse := base64.RawURLEncoding.EncodeToString(hash[:24])
	target := "fid"
	if in.TargetKind == "fcm_token" {
		target = "token"
	}
	notification := map[string]any{"title": "BOOHTACORD", "body": body}
	message := map[string]any{target: in.Target, "data": map[string]string{dataKey: string(in.Payload)}, "notification": notification}
	if in.Platform == "android" {
		message["android_v2"] = map[string]any{"ttl": strconv.Itoa(ttl) + "s", "collapse_key": collapse, "restricted_package_name": "ru.boohtacord.app",
			"remote_notification": map[string]any{"notification": map[string]any{"title": "BOOHTACORD", "body": body, "channel_id": "boohtacord_remote_v1", "tag": "bcn:" + binding + ":" + collapse, "default_sound": true, "visibility": "PRIVATE"}}}
	}
	if in.Platform == "ios" {
		message["apns"] = map[string]any{"headers": map[string]string{"apns-expiration": strconv.FormatInt(in.ExpiresAt.Unix(), 10), "apns-priority": "10", "apns-push-type": "alert", "apns-collapse-id": collapse}, "payload": map[string]any{"aps": map[string]any{"alert": notification, "sound": "default", "thread-id": collapse}}}
	}
	return json.Marshal(map[string]any{"message": message})
}
func strict(raw []byte, value any) error {
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	if err := d.Decode(value); err != nil {
		return err
	}
	if d.Decode(&struct{}{}) != io.EOF {
		return ErrInvalid
	}
	return nil
}
