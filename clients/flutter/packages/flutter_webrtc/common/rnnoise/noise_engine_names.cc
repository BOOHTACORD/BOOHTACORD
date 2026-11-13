#include "rnnoise_capture_processor.h"
#include <cstring>
namespace boohta {
const char* NoiseEngineName(RnnoiseCaptureProcessor::Engine engine) {
  switch (engine) {
    case RnnoiseCaptureProcessor::Engine::kOff: return "off";
    case RnnoiseCaptureProcessor::Engine::kBrowser: return "browser";
    case RnnoiseCaptureProcessor::Engine::kRnnoise: return "rnnoise";
    case RnnoiseCaptureProcessor::Engine::kDeepFilter: return "deepfilter";
    case RnnoiseCaptureProcessor::Engine::kUnknown: return "unknown";
  }
  return "browser";
}
bool ParseNoiseEngine(const char* value, RnnoiseCaptureProcessor::Engine* engine) {
  if (!value || !engine) return false;
  if (!std::strcmp(value, "off")) *engine = RnnoiseCaptureProcessor::Engine::kOff;
  else if (!std::strcmp(value, "browser")) *engine = RnnoiseCaptureProcessor::Engine::kBrowser;
  else if (!std::strcmp(value, "rnnoise")) *engine = RnnoiseCaptureProcessor::Engine::kRnnoise;
  else if (!std::strcmp(value, "deepfilter")) *engine = RnnoiseCaptureProcessor::Engine::kDeepFilter;
  else return false;
  return true;
}
}
