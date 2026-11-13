#include <boohta_rnnoise_capture_processor.h>
#include <cassert>

int main() {
  using Processor = boohta::RnnoiseCaptureProcessor;
  Processor processor;
  processor.Initialize(48000, 1);
  assert(processor.supported());
  Processor::Engine engine;
  assert(boohta::ParseNoiseEngine("rnnoise", &engine));
  assert(engine == Processor::Engine::kRnnoise);
  assert(boohta::NoiseEngineName(engine));
  processor.SetEngine(engine);
  float silence[480] = {};
  assert(processor.Process(silence, 480, 480));
  processor.SetEngine(Processor::Engine::kDeepFilter);
  assert(!processor.supported());
  assert(!processor.Process(silence, 480, 480));
  processor.Reset();
}
