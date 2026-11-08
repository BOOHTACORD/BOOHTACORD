package coordinateroster

import (
	"bytes"
	"context"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
	normalizeroster "voice-platform/backend/internal/voice/normalize_roster"
)

func (c *Coordinator) worker(parent context.Context) {
	for {
		select {
		case <-parent.Done():
			return
		case work := <-c.jobs:
			ctx, cancel, ok := c.prepare(parent, work)
			if !ok {
				continue
			}
			result, err := c.lister.List(ctx, work.account.id)
			if ctx.Err() != nil {
				err = ctx.Err()
			}
			cancel()
			var encoded []byte
			if err == nil {
				result, encoded, err = normalizeroster.Canonicalize(result, c.config.MaxSnapshotBytes)
			}
			if parent.Err() == nil {
				c.finish(work, result, encoded, err == nil)
			}
		}
	}
}

func (c *Coordinator) prepare(parent context.Context, work job) (context.Context, context.CancelFunc, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	a := work.account
	current := !c.closed && c.accounts[a.id] == a
	valid := current && a.pending && a.epoch == work.epoch
	if current && !valid {
		a.pending, a.dirty = false, true
	}
	var ctx context.Context
	var cancel context.CancelFunc
	if valid {
		ctx, cancel = context.WithTimeout(parent, c.config.ReadTimeout)
		a.cancel = cancel
	}
	c.scheduleWaiting()
	return ctx, cancel, valid
}

func (c *Coordinator) finish(work job, result roster.Result, encoded []byte, available bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	defer c.scheduleWaiting()
	a := work.account
	if c.closed || c.accounts[a.id] != a {
		return
	}
	a.cancel = nil
	a.pending = false
	if a.epoch != work.epoch {
		return
	}
	changed := !a.have || a.available != available || (available && !bytes.Equal(a.last, encoded))
	if changed {
		a.revision++
	}
	a.have, a.available = true, available
	if available {
		a.last = encoded
	}
	a.state = State{Generation: c.generation, Revision: a.revision, ObservedAt: time.Now().UTC(), Unavailable: !available, Roster: result}
	for sub := range a.subs {
		if !changed && sub.initialized {
			continue
		}
		sub.initialized = true
		select {
		case <-sub.events:
		default:
		}
		sub.events <- copyState(a.state)
	}
}

func copyState(state State) State {
	if state.Unavailable {
		state.Roster = roster.Result{}
		return state
	}
	channels := make([]roster.ChannelRoster, len(state.Roster.Channels))
	for i, channel := range state.Roster.Channels {
		participants := make([]roster.Participant, len(channel.Participants))
		copy(participants, channel.Participants)
		channels[i] = roster.ChannelRoster{ChannelID: channel.ChannelID, Participants: participants}
	}
	state.Roster.Channels = channels
	return state
}
