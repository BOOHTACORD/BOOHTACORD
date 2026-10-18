package eventhub

import "context"

// PublishToAccountsTransient sends a private invalidation without writing it
// to the replay journal. The recipient reloads the authorized snapshot.
func (hub *Hub) PublishToAccountsTransient(accountIDs []string, event Event) {
	if hub == nil || len(accountIDs) == 0 {
		return
	}
	targets := make(map[string]struct{}, len(accountIDs))
	for _, accountID := range accountIDs {
		if accountID != "" {
			targets[accountID] = struct{}{}
		}
	}
	if len(targets) == 0 {
		return
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	for subscription := range hub.subscribers {
		if subscription.dropped {
			continue
		}
		if _, targeted := targets[subscription.accountID]; targeted {
			hub.deliverLocked(subscription, event)
		}
	}
}

func (subscription *Subscription) AccountID() string {
	if subscription == nil {
		return ""
	}
	return subscription.accountID
}

// PublishToAccounts delivers a private event only to authenticated connections
// belonging to the supplied accounts. An empty target set never broadcasts.
func (hub *Hub) PublishToAccounts(accountIDs []string, event Event) {
	ctx, cancel := backgroundWriteContext()
	defer cancel()
	_ = hub.publishToAccounts(ctx, accountIDs, event, false)
}
func (hub *Hub) PublishToAccountsContext(ctx context.Context, accountIDs []string, event Event) error {
	return hub.publishToAccounts(ctx, accountIDs, event, false)
}

// PublishToAccountsDurable must persist a private hint before its outbox is
// marked emitted. It succeeds even when no recipient currently has a socket.
func (hub *Hub) PublishToAccountsDurable(ctx context.Context, accountIDs []string, event Event) error {
	return hub.publishToAccounts(ctx, accountIDs, event, true)
}

func (hub *Hub) publishToAccounts(ctx context.Context, accountIDs []string, event Event, requireJournal bool) error {
	if hub == nil || len(accountIDs) == 0 {
		return ErrJournalUnavailable
	}
	hub.publishMu.Lock()
	defer hub.publishMu.Unlock()
	targets := make(map[string]struct{}, len(accountIDs))
	for _, accountID := range accountIDs {
		if accountID != "" {
			targets[accountID] = struct{}{}
		}
	}
	if len(targets) == 0 {
		return ErrJournalUnavailable
	}
	recipients := make([]string, 0, len(targets))
	for accountID := range targets {
		recipients = append(recipients, accountID)
	}
	var err error
	event, err = hub.persist(ctx, event, recipients, requireJournal)
	if err != nil {
		return err
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	for subscription := range hub.subscribers {
		if subscription.dropped {
			continue
		}
		if _, targeted := targets[subscription.accountID]; targeted {
			hub.deliverLocked(subscription, event)
		}
	}
	return nil
}
