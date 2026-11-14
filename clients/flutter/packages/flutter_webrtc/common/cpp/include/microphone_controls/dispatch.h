#ifndef BOOHTA_MICROPHONE_DISPATCH_H_
#define BOOHTA_MICROPHONE_DISPATCH_H_
#include "flutter_common.h"
#include "rnnoise_capture_processor.h"
namespace flutter_webrtc_plugin {
inline bool HandleMicrophoneControls(const MethodCallProxy& call,
    MethodResultProxy* result, boohta::RnnoiseCaptureProcessor& processor) {
  const auto& name = call.method_name();
  if (name == "getNoiseSuppressionCapabilities") {
    processor.preflight.Start();
    EncodableMap capabilities;
    capabilities[EncodableValue("rnnoiseModelId")] = EncodableValue(processor.ModelId());
    capabilities[EncodableValue("rnnoisePreflightState")] = EncodableValue(processor.preflight.state());
    capabilities[EncodableValue("rnnoiseP95Us")] = EncodableValue(processor.preflight.p95_us());
    capabilities[EncodableValue("rnnoiseMaxUs")] = EncodableValue(processor.preflight.max_us());
    if (const auto model = processor.DeepFilterModelId())
      capabilities[EncodableValue("deepfilterModelId")] = EncodableValue(model);
    result->Success(EncodableValue(capabilities));
    return true;
  }
  if (name != "setMicrophoneControls" && name != "getMicrophoneControlsState") return false;
  auto& c = processor.controls;
  if (name == "setMicrophoneControls") {
    if (!call.arguments()) { result->Error("Bad Arguments", "controls required"); return true; }
    const auto params = GetValue<EncodableMap>(*call.arguments());
    c.Configure(static_cast<float>(findDouble(params, "vadThresholdDb")),
        static_cast<float>(findDouble(params, "microphoneGainPercent")),
        findBoolean(params, "vad"), findBoolean(params, "agc"), findBoolean(params, "enabled"));
  }
  EncodableMap state;
  state[EncodableValue("status")] = EncodableValue(processor.sample_rate() == 0 ? "initializing" :
      !c.supported() ? "unsupported" : c.applied() ? "active" : "initializing");
  state[EncodableValue("levelDb")] = EncodableValue(static_cast<double>(c.level_db()));
  state[EncodableValue("clipping")] = EncodableValue(c.clipping());
  state[EncodableValue("gateOpen")] = EncodableValue(c.gate_open());
  result->Success(EncodableValue(state));
  return true;
}
}
#endif
