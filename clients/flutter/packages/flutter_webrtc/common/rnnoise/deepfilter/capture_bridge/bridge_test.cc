#include "bridge.h"
#include "../worker_step/worker.h"
#include <cassert>
#include <limits>

using namespace boohta::deepfilter;

struct IdentityEngine {
  bool Reset() { return true; }
  bool Process(AudioFrame& frame) { for (float& sample : frame.samples) sample *= 0.5f; return true; }
};

int main() {
  CaptureBridge<4> bridge;
  AudioFrame frame{};
  float pcm[480];
  for (float& sample : pcm) sample = 16384.f;
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::no_frame);
  for (float sample : pcm) assert(sample == 0.f);
  assert(bridge.WorkerPop(1, frame));
  for (float sample : frame.samples) assert(sample == 0.5f);
  frame.samples.fill(-0.25f);
  assert(bridge.WorkerPush(frame));
  for (float& sample : pcm) sample = -32768.f;
  std::uint64_t sequence = 99;
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 1, false, &sequence) == ExchangeStatus::ready);
  assert(sequence == 0);
  for (float sample : pcm) assert(sample == -8192.f);
  assert(bridge.WorkerPop(1, frame));
  for (float sample : frame.samples) assert(sample == -1.f);
  assert(bridge.Capture(pcm, 480, 480, 44100, 1, 1, false) == ExchangeStatus::invalid_audio);
  for (float sample : pcm) assert(sample == -8192.f);
  assert(bridge.Capture(pcm, 479, 480, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  assert(bridge.Capture(pcm, 480, 479, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  assert(bridge.Capture(pcm, 480, 480, 48000, 2, 1, false) == ExchangeStatus::invalid_audio);
  assert(bridge.Capture(nullptr, 480, 480, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  pcm[0] = std::numeric_limits<float>::quiet_NaN();
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  assert(pcm[0] != pcm[0]);
  pcm[0] = 32769.f;
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  assert(pcm[0] == 32769.f);
  for (float& sample : pcm) sample = 100.f;
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 2, true) == ExchangeStatus::no_frame);
  for (float sample : pcm) assert(sample == 0.f);
  assert(!bridge.WorkerPop(2, frame));

  pcm[0] = std::numeric_limits<float>::quiet_NaN();
  assert(bridge.Capture(pcm, 480, 480, 48000, 1, 3, true) == ExchangeStatus::no_frame);
  for (float sample : pcm) assert(sample == 0.f);

  CaptureBridge<2> overloaded;
  for (float& sample : pcm) sample = 8192.f;
  assert(overloaded.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::no_frame);
  for (float& sample : pcm) sample = 8192.f;
  assert(overloaded.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::no_frame);
  for (float& sample : pcm) sample = 8192.f;
  assert(overloaded.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::overload);
  for (float sample : pcm) assert(sample == 8192.f);

  CaptureBridge<2> bad_output;
  assert(bad_output.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::no_frame);
  assert(bad_output.WorkerPop(1, frame));
  frame.samples[0] = std::numeric_limits<float>::quiet_NaN();
  assert(bad_output.WorkerPush(frame));
  for (float& sample : pcm) sample = 16384.f;
  assert(bad_output.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::invalid_audio);
  for (float sample : pcm) assert(sample == 16384.f);

  CaptureBridge<4> integrated;
  IdentityEngine engine;
  WorkerStep<IdentityEngine, 4> step(engine);
  assert(integrated.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::no_frame);
  assert(step.Run(integrated.WorkerExchange(), 1) == WorkerStatus::processed);
  for (float& sample : pcm) sample = 1234.f;
  assert(integrated.Capture(pcm, 480, 480, 48000, 1, 1, false) == ExchangeStatus::ready);
  for (float sample : pcm) assert(sample == 8192.f);
}
