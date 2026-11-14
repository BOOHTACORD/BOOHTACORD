package listmembers

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
)

const defaultLimit = 50
const maxLimit = 100

var (
	ErrInvalidInput   = errors.New("invalid member list input")
	ErrMemberNotFound = errors.New("member not found")
)

type Input struct {
	Cursor string
	Limit  int
}
type Presence string

const (
	PresenceOnline  Presence = "online"
	PresenceOffline Presence = "offline"
	PresenceUnknown Presence = "unknown"
	PresenceIdle    Presence = "idle"
)

type Member struct {
	ID, Login, DisplayName, Role, AvatarURL string
	HasAvatar                               bool
	Presence                                Presence
	Revision                                int64
}
type Result struct {
	Members    []Member
	NextCursor string
}
type Store interface {
	List(context.Context, string, int) ([]Member, error)
	Find(context.Context, string) (Member, error)
}
type PresenceReader interface{ IsOnline(string) bool }
type PresenceStateReader interface{ PresenceState(string) string }
type Service struct {
	store    Store
	presence PresenceReader
}

func New(store Store, presence ...PresenceReader) Service {
	service := Service{store: store}
	if len(presence) > 0 {
		service.presence = presence[0]
	}
	return service
}

func (service Service) List(ctx context.Context, input Input) (Result, error) {
	if input.Limit < 0 || input.Limit > maxLimit || (input.Cursor != "" && !validUUID(input.Cursor)) {
		return Result{}, ErrInvalidInput
	}
	limit := input.Limit
	if limit == 0 {
		limit = defaultLimit
	}
	members, err := service.store.List(ctx, input.Cursor, limit+1)
	if err != nil {
		return Result{}, fmt.Errorf("list guild members: %w", err)
	}
	result := Result{Members: append([]Member{}, members...)}
	if len(members) > limit {
		result.Members = members[:limit]
		result.NextCursor = result.Members[len(result.Members)-1].ID
	}
	for i := range result.Members {
		result.Members[i].Presence = service.memberPresence(result.Members[i].ID)
		if result.Members[i].HasAvatar {
			result.Members[i].AvatarURL = "/api/v1/members/" + result.Members[i].ID + "/avatar"
		}
	}
	return result, nil
}

func (service Service) Get(ctx context.Context, memberID string) (Member, error) {
	if !validUUID(memberID) {
		return Member{}, ErrInvalidInput
	}
	member, err := service.store.Find(ctx, memberID)
	if errors.Is(err, ErrMemberNotFound) {
		return Member{}, ErrMemberNotFound
	}
	if err != nil {
		return Member{}, fmt.Errorf("get guild member: %w", err)
	}
	if member.HasAvatar {
		member.AvatarURL = "/api/v1/members/" + member.ID + "/avatar"
	}
	member.Presence = service.memberPresence(member.ID)
	return member, nil
}

func (service Service) memberPresence(accountID string) Presence {
	if service.presence == nil {
		return PresenceUnknown
	}
	if states, ok := service.presence.(PresenceStateReader); ok {
		switch states.PresenceState(accountID) {
		case "online":
			return PresenceOnline
		case "idle":
			return PresenceIdle
		default:
			return PresenceOffline
		}
	}
	if service.presence.IsOnline(accountID) {
		return PresenceOnline
	}
	return PresenceOffline
}

func validUUID(value string) bool { _, err := uuid.Parse(value); return err == nil }
