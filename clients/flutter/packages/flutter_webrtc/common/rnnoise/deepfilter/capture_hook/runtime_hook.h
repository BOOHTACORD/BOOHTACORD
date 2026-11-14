#ifndef BOOHTA_DEEPFILTER_RUNTIME_HOOK_H_
#define BOOHTA_DEEPFILTER_RUNTIME_HOOK_H_
#include "interface.h"
#include "../worker_runtime/runtime.h"

namespace boohta::deepfilter {
// The control owner launches the runtime before offering this hook and joins
// it only after capture has stopped. Reset does not load a model or join.
template <typename Engine, std::size_t Capacity>
class RuntimeHook final : public CaptureHook {
 public:
  explicit RuntimeHook(WorkerRuntime<Engine, Capacity>& runtime, const char* model_id = nullptr) noexcept
      : runtime_(runtime), model_id_(model_id) {}
  const char* ModelId() const noexcept override { return model_id_; }
  void Reset(bool enabled) noexcept override { if (enabled) runtime_.Start(); else runtime_.Mute(); }
  bool Available() const noexcept override { return runtime_.Available(); }
  HookReadiness Readiness() const noexcept override {
    if (runtime_.Prepared()) return HookReadiness::ready;
    return runtime_.Snapshot().state == LifecycleState::starting ? HookReadiness::preparing : HookReadiness::failed;
  }
  GuardStatus Capture(float* pcm, int frames, int capacity, int rate, int channels) noexcept override {
    return runtime_.Capture(pcm, frames, capacity, rate, channels);
  }
 private:
  WorkerRuntime<Engine, Capacity>& runtime_;
  const char* const model_id_; // Borrowed static identity; owner outlives capture.
};
}  // namespace boohta::deepfilter
#endif
