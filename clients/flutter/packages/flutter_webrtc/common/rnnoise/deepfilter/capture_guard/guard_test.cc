#include "guard.h"
#include <cassert>
#include <limits>

using namespace boohta::deepfilter;

struct FakeBridge {
  Lifecycle* lifecycle = nullptr;
  ExchangeStatus result = ExchangeStatus::ready;
  bool mute_during_capture = false, restart_during_capture = false;
  ExchangeStatus Capture(float* pcm, int, int, int, int, std::uint64_t, bool, std::uint64_t*) {
    for (int i = 0; i < 480; ++i) pcm[i] = 123.f;
    if (mute_during_capture) lifecycle->Mute();
    if (restart_during_capture) lifecycle->Start();
    return result;
  }
};

int main() {
  Lifecycle life;
  FakeBridge bridge{&life};
  CaptureGuard<FakeBridge> guard(life, bridge);
  float pcm[480];
  const auto fill = [&] { for (float& x : pcm) x = 234.f; };
  fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::fallback);
  for (float x : pcm) assert(x == 234.f);
  auto generation = life.Start();
  std::uint64_t sequence = 17;
  assert(guard.Process(pcm, 480, 480, 48000, 1, &sequence) == GuardStatus::ready);
  assert(sequence == std::numeric_limits<std::uint64_t>::max());
  for (float x : pcm) assert(x == 123.f);
  assert(life.Activate(generation));
  bridge.result = ExchangeStatus::no_frame; fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::underrun);
  bridge.result = ExchangeStatus::overload; fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::fallback);
  for (float x : pcm) assert(x == 234.f);
  assert(life.Snapshot().state == LifecycleState::failed);
  life.Start(); bridge.result = ExchangeStatus::ready;
  bridge.mute_during_capture = true; fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::stale);
  for (float x : pcm) assert(x == 0.f);
  bridge.mute_during_capture = false; fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::muted);
  for (float x : pcm) assert(x == 0.f);
  life.Start(); bridge.restart_during_capture = true; fill();
  assert(guard.Process(pcm, 480, 480, 48000, 1) == GuardStatus::stale);
  for (float x : pcm) assert(x == 0.f);
  fill();
  assert(guard.Process(pcm, 480, 479, 48000, 1) == GuardStatus::invalid_format);
  for (float x : pcm) assert(x == 234.f);
}
