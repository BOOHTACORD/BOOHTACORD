package eligibility

type Input struct {
	TTLMS             int64  `json:"ttl_ms,omitempty"`
	Version           int    `json:"version"`
	Kind              string `json:"kind"`
	ActorID           string `json:"actor_id"`
	RecipientID       string `json:"recipient_id"`
	Mentioned         bool   `json:"mentioned"`
	Read              bool   `json:"read"`
	Deleted           bool   `json:"deleted"`
	Archived          bool   `json:"archived"`
	Revoked           bool   `json:"revoked"`
	OperatorAvailable bool   `json:"operator_available"`
	AccountEnabled    bool   `json:"account_enabled"`
	DeviceConsent     bool   `json:"device_consent"`
	Mode              string `json:"mode"`
	PausedUntilMS     int64  `json:"paused_until_ms"`
	NowMS             int64  `json:"now_ms"`
	OccurredAtMS      int64  `json:"occurred_at_ms"`
}

type Result struct {
	Eligible bool   `json:"eligible"`
	Reason   string `json:"reason"`
}

const maxEpochMS = int64(9007199254740991)

func Evaluate(in Input) Result {
	if in.Version != 1 {
		return Result{false, "unsupported_version"}
	}
	if in.ActorID == "" || in.RecipientID == "" {
		return Result{false, "invalid"}
	}
	ttl := in.TTLMS
	if ttl == 0 {
		ttl = 3600000
	}
	if ttl < 60000 || ttl > 86400000 {
		return Result{false, "invalid"}
	}
	switch in.Mode {
	case "all", "mentions", "none":
	default:
		return Result{false, "invalid"}
	}
	if in.PausedUntilMS < 0 || in.NowMS < 0 || in.OccurredAtMS < 0 ||
		in.NowMS > maxEpochMS || in.OccurredAtMS > maxEpochMS ||
		in.PausedUntilMS > maxEpochMS || in.OccurredAtMS > in.NowMS {
		return Result{false, "invalid"}
	}
	if !in.OperatorAvailable {
		return Result{false, "unavailable"}
	}
	if !in.AccountEnabled || !in.DeviceConsent {
		return Result{false, "no_consent"}
	}
	if in.ActorID == in.RecipientID {
		return Result{false, "self"}
	}
	if in.Kind != "DM" && in.Kind != "TEXT" {
		return Result{false, "event_kind"}
	}
	if in.Deleted {
		return Result{false, "deleted"}
	}
	if in.Archived {
		return Result{false, "archived"}
	}
	if in.Revoked {
		return Result{false, "revoked"}
	}
	if in.Read {
		return Result{false, "read"}
	}
	if in.NowMS-in.OccurredAtMS >= ttl {
		return Result{false, "expired"}
	}
	if in.NowMS < in.PausedUntilMS {
		return Result{false, "paused"}
	}
	if in.Mode == "none" {
		return Result{false, "muted"}
	}
	if in.Mode == "mentions" && !in.Mentioned {
		return Result{false, "not_mentioned"}
	}
	return Result{true, "eligible"}
}
