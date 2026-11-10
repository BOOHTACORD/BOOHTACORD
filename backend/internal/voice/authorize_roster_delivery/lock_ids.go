package authorizerosterdelivery

import (
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type lockedIDs struct{ channels, accounts, leases []pgtype.UUID }

func snapshotIDs(snapshot roster.Result) (lockedIDs, error) {
	var ids lockedIDs
	channels, accounts, leases := map[string]bool{}, map[string]bool{}, map[string]bool{}
	add := func(value string, seen map[string]bool, result *[]pgtype.UUID) error {
		parsed, err := uuid.Parse(value)
		if err != nil {
			return err
		}
		if !seen[parsed.String()] {
			seen[parsed.String()] = true
			*result = append(*result, pgtype.UUID{Bytes: parsed, Valid: true})
		}
		return nil
	}
	for _, channel := range snapshot.Channels {
		if err := add(channel.ChannelID, channels, &ids.channels); err != nil {
			return lockedIDs{}, err
		}
		for _, member := range channel.Participants {
			if err := add(member.AccountID, accounts, &ids.accounts); err != nil {
				return lockedIDs{}, err
			}
			if err := add(member.LeaseID, leases, &ids.leases); err != nil {
				return lockedIDs{}, err
			}
		}
	}
	return ids, nil
}
