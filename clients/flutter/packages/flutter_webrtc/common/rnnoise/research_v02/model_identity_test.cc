#include "rnnoise_capture_processor.h"
#include <cstring>

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  const char* model = boohta::RnnoiseCaptureProcessor::ModelId();
  if (!model || std::strcmp(model, argv[1])) return 1;
  // Engine selection does not change the compiled model identity.
  boohta::RnnoiseCaptureProcessor processor;
  for (auto engine : {boohta::RnnoiseCaptureProcessor::Engine::kOff,
                      boohta::RnnoiseCaptureProcessor::Engine::kBrowser,
                      boohta::RnnoiseCaptureProcessor::Engine::kRnnoise}) {
    processor.SetEngine(engine);
    if (std::strcmp(processor.ModelId(), model)) return 1;
  }
  return 0;
}
