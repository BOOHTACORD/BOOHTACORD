#ifndef BOOHTA_DEEPFILTER_EXPERIMENTAL_OWNER_H_
#define BOOHTA_DEEPFILTER_EXPERIMENTAL_OWNER_H_
#include "../capture_hook/runtime_hook.h"
#include "../verified_engine/engine.h"
#include <memory>
namespace boohta::deepfilter {
// The caller must detach and stop capture before destroying this owner.
class ExperimentalOwner {
 public:
  bool Open(const std::wstring& dll, const char* dll_hash,
            const std::wstring& model, const char* model_hash) {
    if (engine_) return false;
    auto engine = std::make_unique<VerifiedEngine>();
    if (!engine->Open(dll, dll_hash, model, model_hash)) return false;
    auto runtime = std::make_unique<Runtime>(*engine, 4);
    auto hook = std::make_unique<Hook>(*runtime);
    if (!runtime->Launch()) return false;
    engine_ = std::move(engine);
    runtime_ = std::move(runtime);
    hook_ = std::move(hook);
    return true;
  }
  CaptureHook* hook() const noexcept { return hook_.get(); }
 private:
  using Runtime = WorkerRuntime<VerifiedEngine, 8>;
  using Hook = RuntimeHook<VerifiedEngine, 8>;
  // Reverse destruction joins the worker before unloading engine resources.
  std::unique_ptr<VerifiedEngine> engine_;
  std::unique_ptr<Runtime> runtime_;
  std::unique_ptr<Hook> hook_;
};
}
#endif
