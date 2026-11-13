#ifndef BOOHTA_DEEPFILTER_WORKER_STEP_H_
#define BOOHTA_DEEPFILTER_WORKER_STEP_H_

#include "../frame_exchange/exchange.h"

namespace boohta::deepfilter {
enum class WorkerStatus { idle, processed, engine_error, output_overload };

// Called only on the worker thread. Engine initialization/reset and inference
// may allocate; they must never execute on the capture callback. The owner
// must publish failures to the control path and change generation on recovery.
template <typename Engine, std::size_t Capacity>
class WorkerStep {
 public:
  explicit WorkerStep(Engine& engine) : engine_(engine) {}
  WorkerStatus Run(FrameExchange<Capacity>& exchange, std::uint64_t generation) noexcept {
    if (poisoned_ && initialized_ && generation == generation_) return WorkerStatus::engine_error;
    AudioFrame frame{};
    if (!exchange.WorkerPop(generation, frame)) return WorkerStatus::idle;
    const auto sequence = frame.sequence;
    try {
      if (!initialized_ || generation != generation_) {
        initialized_ = true; generation_ = generation; poisoned_ = false;
        if (!engine_.Reset()) { poisoned_ = true; return WorkerStatus::engine_error; }
      }
      if (!engine_.Process(frame)) { poisoned_ = true; return WorkerStatus::engine_error; }
      frame.generation = generation; frame.sequence = sequence;
      for (float sample : frame.samples) {
        if (!std::isfinite(sample) || std::fabs(sample) > 1.0f) {
          poisoned_ = true; return WorkerStatus::engine_error;
        }
      }
      if (!exchange.WorkerPush(frame)) { poisoned_ = true; return WorkerStatus::output_overload; }
      return WorkerStatus::processed;
    } catch (...) { poisoned_ = true; return WorkerStatus::engine_error; }
  }
 private:
  Engine& engine_;
  std::uint64_t generation_ = 0;
  bool initialized_ = false, poisoned_ = false;
};
}  // namespace boohta::deepfilter
#endif
