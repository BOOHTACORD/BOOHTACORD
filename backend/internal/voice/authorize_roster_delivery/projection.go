package authorizerosterdelivery

import roster "voice-platform/backend/internal/voice/list_connected_participants"

func matches(snapshot roster.Result, visible []roster.Channel) bool {
	if len(snapshot.Channels) != len(visible) {
		return false
	}
	channels := make(map[string]roster.Channel, len(visible))
	for _, channel := range visible {
		if channel.ID == "" {
			return false
		}
		if _, exists := channels[channel.ID]; exists {
			return false
		}
		channels[channel.ID] = channel
	}
	seen := make(map[string]bool, len(snapshot.Channels))
	for _, channel := range snapshot.Channels {
		current, ok := channels[channel.ChannelID]
		if !ok || seen[channel.ChannelID] || !participantsMatch(channel.Participants, current.Leases) {
			return false
		}
		seen[channel.ChannelID] = true
	}
	return true
}

func participantsMatch(participants []roster.Participant, leases []roster.Lease) bool {
	current := make(map[string]roster.Lease, len(leases))
	for _, lease := range leases {
		if lease.ID == "" {
			return false
		}
		if _, exists := current[lease.ID]; exists {
			return false
		}
		current[lease.ID] = lease
	}
	accounts, usedLeases := make(map[string]bool, len(participants)), make(map[string]bool, len(participants))
	for _, participant := range participants {
		lease, ok := current[participant.LeaseID]
		if !ok || participant.AccountID == "" || accounts[participant.AccountID] || usedLeases[participant.LeaseID] || lease.AccountID != participant.AccountID || lease.DisplayName != participant.DisplayName {
			return false
		}
		accounts[participant.AccountID], usedLeases[participant.LeaseID] = true, true
	}
	return true
}
