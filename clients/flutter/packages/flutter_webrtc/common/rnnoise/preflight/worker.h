#ifndef BOOHTA_RNNOISE_PREFLIGHT_WORKER_H_
#define BOOHTA_RNNOISE_PREFLIGHT_WORKER_H_
#include "warmup.h"
#include "../deepfilter/preflight/benchmark.h"
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <memory>
#include <thread>

namespace boohta {
// Own model state, synthetic PCM and thread. Start/poll/destruction are control
// operations. No model, allocation, lock, join or timer is added to capture.
class RnnoisePreflight {
 public:
  ~RnnoisePreflight() { if (worker_.joinable()) worker_.join(); }
  bool Start() noexcept {
    int idle = 0;
    if (!state_.compare_exchange_strong(idle, 1)) return false;
    try { worker_ = std::thread([this] { Run(); }); }
    catch (...) { state_.store(3, std::memory_order_release); return false; }
    return true;
  }
  int state() const { return state_.load(std::memory_order_acquire); }
  std::int64_t p95_us() const { return p95_.load(); }
  std::int64_t max_us() const { return max_.load(); }
 private:
  void Run() noexcept {
    try {
      std::unique_ptr<DenoiseState, decltype(&rnnoise_destroy)> model(
          static_cast<DenoiseState*>(std::malloc(rnnoise_get_size())), rnnoise_destroy);
      if (!model || rnnoise_init(model.get()) != 0) { state_.store(3); return; }
      WarmRnnoiseFft(model.get());
      if (rnnoise_init(model.get()) != 0) { state_.store(3); return; }
      const auto result = deepfilter::RunPreflight([&](deepfilter::AudioFrame& frame) {
        for (float& value : frame.samples) value *= 32768.f;
        const auto probability = rnnoise_process_frame(model.get(), frame.samples.data(), frame.samples.data());
        for (float& value : frame.samples) value /= 32768.f;
        return std::isfinite(probability) && probability >= 0 && probability <= 1;
      }, [] {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
      });
      p95_.store(result.p95_us); max_.store(result.max_us);
      state_.store(result.ready ? 2 : 3, std::memory_order_release);
    } catch (...) { state_.store(3, std::memory_order_release); }
  }
  std::atomic<int> state_{0}; // idle, running, passed, failed
  std::atomic<std::int64_t> p95_{0}, max_{0};
  std::thread worker_;
};
}
#endif
