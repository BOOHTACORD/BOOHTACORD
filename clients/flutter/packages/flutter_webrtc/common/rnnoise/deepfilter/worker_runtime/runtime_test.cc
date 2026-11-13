#include "runtime.h"
#include <atomic>
#include <cassert>
#include <chrono>
#include <thread>

using namespace boohta::deepfilter;
struct FakeEngine {
  std::atomic<int> resets{0}, calls{0}, closes{0};
  std::atomic<bool> fail{false};
  bool Reset() { ++resets; return true; }
  bool Process(AudioFrame& frame) {
    ++calls;
    if (fail.load()) return false;
    for (float& sample : frame.samples) sample *= 0.5f;
    return true;
  }
  bool Close() { ++closes; return true; }
};

int main() {
  FakeEngine engine;
  WorkerRuntime<FakeEngine, 8> runtime(engine, 0);
  assert(runtime.Launch());
  assert(!runtime.Launch());
  const auto generation = runtime.Start();
  assert(generation != 0);
  float pcm[480];
  for (float& sample : pcm) sample = 16384.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::underrun);
  auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (runtime.Snapshot().state != LifecycleState::active && std::chrono::steady_clock::now() < deadline)
    std::this_thread::yield();
  assert(runtime.Snapshot().state == LifecycleState::active);
  for (float& sample : pcm) sample = 16384.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::ready);
  for (float sample : pcm) assert(sample == 8192.f);
  runtime.Mute();
  for (float& sample : pcm) sample = 300.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::muted);
  for (float sample : pcm) assert(sample == 0.f);
  engine.fail.store(true);
  const auto next = runtime.Start();
  assert(next > generation);
  for (float& sample : pcm) sample = 16384.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::underrun);
  deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (runtime.Snapshot().state != LifecycleState::failed && std::chrono::steady_clock::now() < deadline)
    std::this_thread::yield();
  assert(runtime.Snapshot().state == LifecycleState::failed);
  for (float& sample : pcm) sample = 16384.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::fallback);
  for (float sample : pcm) assert(sample == 16384.f);
  engine.fail.store(false);
  const auto recovered = runtime.Start();
  assert(recovered > next);
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::underrun);
  deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
  while (runtime.Snapshot().state != LifecycleState::active && std::chrono::steady_clock::now() < deadline)
    std::this_thread::yield();
  assert(runtime.Snapshot().state == LifecycleState::active);
  for (float& sample : pcm) sample = 16384.f;
  assert(runtime.Capture(pcm, 480, 480, 48000, 1) == GuardStatus::ready);
  for (float sample : pcm) assert(sample == 8192.f);
  assert(engine.resets.load() >= 3);
  runtime.Shutdown();
  assert(engine.closes.load() == 1);
  assert(runtime.Snapshot().state == LifecycleState::stopped);
}
