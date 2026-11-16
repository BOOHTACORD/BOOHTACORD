package screentelemetryrelay

import (
	"errors"
	"math"
	"regexp"

	screenpreview "voice-platform/backend/internal/media/screen_preview"
)

const (
	EnvelopeVersion      = 1
	MaxEnvelopeBytes     = 2048
	MaxSequence          = uint64(1<<53 - 1)
	MaxMetricAgeMS       = uint32(60_000)
	MaxCapabilityVersion = 16
	MaxDimension         = 16_384
	MaxFPS               = 240
	MaxBitrateBPS        = 100_000_000
	MaxRTTMS             = 60_000
)

var (
	ErrInvalid       = errors.New("invalid screen telemetry")
	ErrDenied        = errors.New("screen telemetry access denied")
	ErrUnavailable   = errors.New("screen telemetry unavailable")
	ErrNoPublication = screenpreview.ErrNoPublication
	ErrStale         = errors.New("stale screen telemetry")
	ErrRateLimited   = errors.New("screen telemetry rate limited")
	ErrCapacity      = errors.New("screen telemetry capacity reached")

	validMediaSessionID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,256}$`)
)

type Availability string

const (
	AvailabilityMeasured         Availability = "measured"
	AvailabilityConfiguredOnly   Availability = "configured_only"
	AvailabilityUnsupported      Availability = "unsupported"
	AvailabilityNotExposed       Availability = "not_exposed"
	AvailabilityPermissionDenied Availability = "permission_denied"
	AvailabilityNotApplicable    Availability = "not_applicable"
	AvailabilityStale            Availability = "stale"
)

type Provenance string

const (
	ProvenanceSenderMeasured Provenance = "sender_measured"
	ProvenanceConfigured     Provenance = "configured"
	ProvenanceUnavailable    Provenance = "unavailable"
)

type Platform string

const (
	PlatformWeb     Platform = "web"
	PlatformAndroid Platform = "android"
	PlatformIOS     Platform = "ios"
	PlatformMacOS   Platform = "macos"
	PlatformWindows Platform = "windows"
)

type ClientKind string

const (
	ClientKindWeb     ClientKind = "web"
	ClientKindFlutter ClientKind = "flutter"
)

// Metric carries one bounded numeric measurement and its explicit availability
// and provenance. Unavailable values never carry a fabricated number.
type Metric struct {
	Value        *float64     `json:"value,omitempty"`
	Availability Availability `json:"availability"`
	Provenance   Provenance   `json:"provenance"`
}

type CategoricalMetric struct {
	Value        *string      `json:"value,omitempty"`
	Availability Availability `json:"availability"`
	Provenance   Provenance   `json:"provenance"`
}

type CaptureMetrics struct {
	Width  Metric `json:"width"`
	Height Metric `json:"height"`
	FPS    Metric `json:"fps"`
}

type EncodeMetrics struct {
	FPS        Metric `json:"fps"`
	BitrateBPS Metric `json:"bitrate_bps"`
}

type TransportMetrics struct {
	PacketLossPercent       Metric            `json:"packet_loss_percent"`
	RTTMS                   Metric            `json:"rtt_ms"`
	QualityLimitationReason CategoricalMetric `json:"quality_limitation_reason"`
}

// ScreenTelemetryEnvelopeV1 is intentionally separate from the durable
// ScreenShareDescriptorV1 configuration metadata.
type ScreenTelemetryEnvelopeV1 struct {
	SchemaVersion         int              `json:"schema_version"`
	MediaSessionID        string           `json:"media_session_id"`
	PublicationGeneration uint64           `json:"publication_generation"`
	Platform              Platform         `json:"platform"`
	ClientKind            ClientKind       `json:"client_kind"`
	CapabilityVersion     int              `json:"capability_version"`
	Sequence              uint64           `json:"sequence"`
	SenderSampleAgeMS     *uint32          `json:"sender_sample_age_ms,omitempty"`
	Capture               CaptureMetrics   `json:"capture"`
	Encode                EncodeMetrics    `json:"encode"`
	Transport             TransportMetrics `json:"transport"`
}

func (value ScreenTelemetryEnvelopeV1) Validate() error {
	if value.SchemaVersion != EnvelopeVersion || !validMediaSessionID.MatchString(value.MediaSessionID) || value.PublicationGeneration == 0 || value.PublicationGeneration > MaxSequence {
		return ErrInvalid
	}
	if value.CapabilityVersion < 1 || value.CapabilityVersion > MaxCapabilityVersion || value.Sequence == 0 || value.Sequence > MaxSequence {
		return ErrInvalid
	}
	if value.SenderSampleAgeMS != nil && *value.SenderSampleAgeMS > MaxMetricAgeMS {
		return ErrInvalid
	}
	switch value.Platform {
	case PlatformWeb:
		if value.ClientKind != ClientKindWeb {
			return ErrInvalid
		}
	case PlatformAndroid, PlatformIOS, PlatformMacOS, PlatformWindows:
		if value.ClientKind != ClientKindFlutter {
			return ErrInvalid
		}
	default:
		return ErrInvalid
	}
	if !validNumeric(value.Capture.Width, 1, MaxDimension, true) || !validNumeric(value.Capture.Height, 1, MaxDimension, true) ||
		!validNumeric(value.Capture.FPS, 0, MaxFPS, false) || !validNumeric(value.Encode.FPS, 0, MaxFPS, false) ||
		!validNumeric(value.Encode.BitrateBPS, 0, MaxBitrateBPS, true) ||
		!validNumeric(value.Transport.PacketLossPercent, 0, 100, false) || !validNumeric(value.Transport.RTTMS, 0, MaxRTTMS, false) ||
		!validQualityReason(value.Transport.QualityLimitationReason) {
		return ErrInvalid
	}
	return nil
}

func validNumeric(metric Metric, minimum, maximum float64, integral bool) bool {
	if metric.Value == nil {
		return unavailable(metric.Availability, metric.Provenance)
	}
	value := *metric.Value
	if math.IsNaN(value) || math.IsInf(value, 0) || value < minimum || value > maximum || integral && math.Trunc(value) != value {
		return false
	}
	switch metric.Availability {
	case AvailabilityMeasured:
		return metric.Provenance == ProvenanceSenderMeasured
	case AvailabilityConfiguredOnly:
		return metric.Provenance == ProvenanceConfigured
	default:
		return false
	}
}

func validQualityReason(metric CategoricalMetric) bool {
	if metric.Value == nil {
		return unavailable(metric.Availability, metric.Provenance)
	}
	if metric.Availability != AvailabilityMeasured || metric.Provenance != ProvenanceSenderMeasured {
		return false
	}
	switch *metric.Value {
	case "none", "bandwidth", "cpu", "encoder":
		return true
	default:
		return false
	}
}

func unavailable(availability Availability, provenance Provenance) bool {
	if provenance != ProvenanceUnavailable {
		return false
	}
	switch availability {
	case AvailabilityUnsupported, AvailabilityNotExposed, AvailabilityPermissionDenied, AvailabilityNotApplicable, AvailabilityStale:
		return true
	default:
		return false
	}
}
