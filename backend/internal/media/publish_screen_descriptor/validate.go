package publish_screen_descriptor

import "strings"

var profileIDs = map[string]bool{
	"P720_15": true, "P720_30": true, "P720_60": true,
	"P1080_15": true, "P1080_30": true, "P1080_60": true,
	"P1440_15": true, "P1440_30": true, "P1440_60": true,
}

var publisherStates = words("idle requesting capturing publishing sharing updating stopping failed")
var viewerStates = words("idle subscribing waiting-first-frame playing suspended recovering ended failed")
var reasonCodes = words("user-request platform-constraint network-adaptation no-subscribers sdk-paused unsupported-profile capture-denied publish-failed superseded session-revoked logout unknown")

func Validate(value Descriptor) bool {
	if value.SchemaVersion != 1 || value.Scope.MediaSessionID == "" || value.Scope.PublicationGeneration == 0 || value.Scope.OperationRevision == 0 || value.ProfileRevision == 0 {
		return false
	}
	if !profileIDs[value.RequestedProfileID] || publisherStates[value.PublisherState] == false || viewerStates[value.ViewerState] == false {
		return false
	}
	if (value.Mode != "motion" && value.Mode != "text") || (value.LayerTopology != "single-layer" && value.LayerTopology != "bounded-simulcast") {
		return false
	}
	if value.EffectiveProfile.Capture.MaxWidth < 2 || value.EffectiveProfile.Capture.MaxHeight < 2 || value.EffectiveProfile.Capture.MaxFPS < 1 {
		return false
	}
	layers := value.EffectiveProfile.Encoding.Layers
	if len(layers) == 0 || len(layers) > 2 || (value.EffectiveProfile.Encoding.Codec != nil && len(*value.EffectiveProfile.Encoding.Codec) > 32) {
		return false
	}
	for _, layer := range layers {
		if layer.Width < 2 || layer.Height < 2 || layer.MaxFPS < 1 || layer.MaxBitrateBPS < 1 || layer.ScaleDownBy < 1 || layer.ScaleDownBy > 16 {
			return false
		}
		if layer.RID != nil && (*layer.RID == "" || len(*layer.RID) > 32) {
			return false
		}
	}
	if value.Capabilities.Simulcast != (len(layers) > 1) || value.ReasonCodes == nil || len(value.ReasonCodes) > 8 {
		return false
	}
	seen := make(map[string]bool, len(value.ReasonCodes))
	for _, reason := range value.ReasonCodes {
		if !reasonCodes[reason] || seen[reason] {
			return false
		}
		seen[reason] = true
	}
	return true
}

func words(values string) map[string]bool {
	result := map[string]bool{}
	for _, value := range strings.Fields(values) {
		result[value] = true
	}
	return result
}
