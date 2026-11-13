#ifndef BOOHTA_DEEPFILTER_WORKER_RUNTIME_H_
#define BOOHTA_DEEPFILTER_WORKER_RUNTIME_H_

#include "../capture_guard/guard.h"
#include "../worker_step/worker.h"
#include <atomic>
#include <chrono>
#include <thread>

namespace boohta::deepfilter {
// Control calls are serialized by the owner and never made on the capture
// callback. Capture has one caller; Shutdown requires capture already stopped.
// Engine and model outlive this object. Publication/mute synchronization and
// fallback recapture are the owning client's responsibilities.
template <typename Engine, std::size_t Capacity>
class WorkerRuntime {
 public:
  explicit WorkerRuntime(Engine& engine, std::size_t startup_frames)
      : engine_(engine), bridge_(startup_frames), guard_(lifecycle_, bridge_), step_(engine) {}
  ~WorkerRuntime() { Shutdown(); }
  WorkerRuntime(const WorkerRuntime&) = delete;
  WorkerRuntime& operator=(const WorkerRuntime&) = delete;

  bool Launch() noexcept {
    if (launched_.load(std::memory_order_acquire) || ever_launched_) return false;
    stopping_.store(false, std::memory_order_release);
    try { worker_ = std::thread(&WorkerRuntime::Run, this); }
    catch (...) { return false; }
    launched_.store(true, std::memory_order_release); ever_launched_ = true; return true;
  }
  bool Available() const noexcept { return launched_.load(std::memory_order_acquire); }
  std::uint64_t Start() noexcept { return Available() ? lifecycle_.Start() : 0; }
  std::uint64_t Mute() noexcept { return lifecycle_.Mute(); }
  LifecycleSnapshot Snapshot() const noexcept { return lifecycle_.Snapshot(); }
  GuardStatus Capture(float* pcm, int frames, int capacity, int rate, int channels,
                      std::uint64_t* emitted_sequence = nullptr) noexcept {
    return guard_.Process(pcm, frames, capacity, rate, channels, emitted_sequence);
  }
  bool Shutdown() noexcept {
    if (!Available()) return !close_failed_.load(std::memory_order_acquire);
    lifecycle_.Stop();
    stopping_.store(true, std::memory_order_release);
    worker_.join();
    launched_.store(false, std::memory_order_release);
    return !close_failed_.load(std::memory_order_acquire);
  }

 private:
  void Run() noexcept {
    while (!stopping_.load(std::memory_order_acquire)) {
      const auto snapshot = lifecycle_.Snapshot();
      if (snapshot.state == LifecycleState::starting || snapshot.state == LifecycleState::active) {
        const auto result = step_.Run(bridge_.WorkerExchange(), snapshot.generation);
        if (result == WorkerStatus::processed) { lifecycle_.Activate(snapshot.generation); continue; }
        if (result != WorkerStatus::idle) lifecycle_.Fail(snapshot.generation);
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    try { if (!engine_.Close()) close_failed_.store(true, std::memory_order_release); }
    catch (...) { close_failed_.store(true, std::memory_order_release); }
  }
  Engine& engine_;
  Lifecycle lifecycle_;
  CaptureBridge<Capacity> bridge_;
  CaptureGuard<CaptureBridge<Capacity>> guard_;
  WorkerStep<Engine, Capacity> step_;
  std::atomic<bool> stopping_{false}, close_failed_{false}, launched_{false};
  std::thread worker_;
  bool ever_launched_ = false;
};
}  // namespace boohta::deepfilter
#endif
