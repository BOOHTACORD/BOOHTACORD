package dispatchdelivery

import "time"

type Job struct {
	ID, OutboxID, BindingID, AccountID, Kind, ConversationID, MessageID, Template, GroupRef, LeaseOwner string
	BindingGeneration, Epoch                                                                            int64
	CreatedAt, ExpiresAt, DueAt                                                                         time.Time
	Attempts                                                                                            int
	AttemptStartedAt                                                                                    *time.Time
	LeaseUntil                                                                                          time.Time
}

func (j Job) Payload() Payload {
	return Payload{Version: 1, Generation: j.BindingGeneration, BindingRef: j.BindingID, NotificationRef: j.ID, GroupRef: j.GroupRef, Template: j.Template, ExpiresAt: j.ExpiresAt.UTC()}
}
