package screentelemetryrelay

import "testing"

func TestScreenTelemetryEnvelopeV1ValidatesMeasuredAndUnavailableValues(t *testing.T) {
	value := validEnvelope()
	if err := value.Validate(); err != nil {
		t.Fatalf("valid envelope rejected: %v", err)
	}

	value.Capture.FPS = Metric{Availability: AvailabilityNotExposed, Provenance: ProvenanceUnavailable}
	value.Transport.QualityLimitationReason = CategoricalMetric{Value: stringPointer("bandwidth"), Availability: AvailabilityMeasured, Provenance: ProvenanceSenderMeasured}
	if err := value.Validate(); err != nil {
		t.Fatalf("unavailable FPS and fixed quality reason rejected: %v", err)
	}
}

func TestScreenTelemetryEnvelopeV1RejectsFabricatedOrUnboundedValues(t *testing.T) {
	tests := map[string]func(*ScreenTelemetryEnvelopeV1){
		"configured FPS cannot be labeled measured": func(value *ScreenTelemetryEnvelopeV1) {
			value.Capture.FPS.Provenance = ProvenanceConfigured
		},
		"unavailable values cannot carry numbers": func(value *ScreenTelemetryEnvelopeV1) {
			value.Capture.FPS = Metric{Value: floatPointer(30), Availability: AvailabilityNotExposed, Provenance: ProvenanceUnavailable}
		},
		"arbitrary text is not a quality reason": func(value *ScreenTelemetryEnvelopeV1) {
			value.Transport.QualityLimitationReason.Value = stringPointer("window title: secret")
		},
		"loss is bounded": func(value *ScreenTelemetryEnvelopeV1) {
			value.Transport.PacketLossPercent.Value = floatPointer(101)
		},
		"stale sample age is bounded": func(value *ScreenTelemetryEnvelopeV1) {
			age := uint32(60_001)
			value.SenderSampleAgeMS = &age
		},
		"sequence is positive":   func(value *ScreenTelemetryEnvelopeV1) { value.Sequence = 0 },
		"platform is fixed enum": func(value *ScreenTelemetryEnvelopeV1) { value.Platform = "windows_server" },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			value := validEnvelope()
			mutate(&value)
			if err := value.Validate(); err == nil {
				t.Fatal("invalid envelope accepted")
			}
		})
	}
}

func validEnvelope() ScreenTelemetryEnvelopeV1 {
	return ScreenTelemetryEnvelopeV1{
		SchemaVersion: 1, MediaSessionID: "session-a", PublicationGeneration: 4,
		Platform: PlatformWeb, ClientKind: ClientKindWeb, CapabilityVersion: 1, Sequence: 1,
		Capture: CaptureMetrics{Width: measured(1920), Height: measured(1080), FPS: measured(30)},
		Encode:  EncodeMetrics{FPS: measured(29), BitrateBPS: measured(1_500_000)},
		Transport: TransportMetrics{
			PacketLossPercent: measured(.4), RTTMS: measured(50),
			QualityLimitationReason: CategoricalMetric{Value: stringPointer("bandwidth"), Availability: AvailabilityMeasured, Provenance: ProvenanceSenderMeasured},
		},
	}
}

func measured(value float64) Metric {
	return Metric{Value: &value, Availability: AvailabilityMeasured, Provenance: ProvenanceSenderMeasured}
}

func floatPointer(value float64) *float64 { return &value }
func stringPointer(value string) *string  { return &value }
