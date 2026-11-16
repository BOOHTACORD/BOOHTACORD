package publish_screen_descriptor

type Principal struct {
	AccountID     string
	SessionDigest [32]byte
}

type Scope struct {
	OriginID              string `json:"origin_id"`
	AccountID             string `json:"account_id"`
	RoomID                string `json:"room_id"`
	MediaSessionID        string `json:"media_session_id"`
	PublicationGeneration uint64 `json:"publication_generation"`
	OperationRevision     uint64 `json:"operation_revision"`
}

type Publication struct {
	TrackSID string
	Scope    Scope
}

type Layer struct {
	RID           *string `json:"rid"`
	Width         int     `json:"width"`
	Height        int     `json:"height"`
	MaxFPS        int     `json:"max_fps"`
	MaxBitrateBPS int     `json:"max_bitrate_bps"`
	ScaleDownBy   float64 `json:"scale_down_by"`
	Active        bool    `json:"active"`
}

type Capture struct {
	MaxWidth  int `json:"max_width"`
	MaxHeight int `json:"max_height"`
	MaxFPS    int `json:"max_fps"`
}

type Encoding struct {
	Codec  *string `json:"codec"`
	Layers []Layer `json:"layers"`
}

type EffectiveProfile struct {
	Capture  Capture  `json:"capture"`
	Encoding Encoding `json:"encoding"`
}

type Capabilities struct {
	LiveUpdate                bool `json:"live_update"`
	RepublishWithoutRecapture bool `json:"republish_without_recapture"`
	Simulcast                 bool `json:"simulcast"`
}

type Descriptor struct {
	SchemaVersion      int              `json:"schema_version"`
	Scope              Scope            `json:"scope"`
	Mode               string           `json:"mode"`
	PublisherState     string           `json:"publisher_state"`
	ViewerState        string           `json:"viewer_state"`
	RequestedProfileID string           `json:"requested_profile_id"`
	EffectiveProfile   EffectiveProfile `json:"effective_profile"`
	LayerTopology      string           `json:"layer_topology"`
	ProfileRevision    uint64           `json:"profile_revision"`
	Capabilities       Capabilities     `json:"capabilities"`
	ReasonCodes        []string         `json:"reason_codes"`
}
