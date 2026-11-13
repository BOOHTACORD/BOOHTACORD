#ifndef BOOHTA_DEEPFILTER_VERIFIED_ENGINE_H_
#define BOOHTA_DEEPFILTER_VERIFIED_ENGINE_H_
#include "../frame_queue/queue.h"
#include "../verified_module/module.h"
#include <memory>
#include <string>

namespace boohta::deepfilter {
// Open on the control thread, then Reset/Process/Close on the worker. Destroy
// only after the worker has joined. No loading or heap work on capture.
class VerifiedEngine {
 public:
  VerifiedEngine() = default;
  ~VerifiedEngine();
  VerifiedEngine(const VerifiedEngine&) = delete;
  VerifiedEngine& operator=(const VerifiedEngine&) = delete;
  bool Open(const std::wstring& dll, const char* dll_hash,
            const std::wstring& model, const char* model_hash);
  bool Reset();
  bool Process(AudioFrame& frame);
  bool Close();
 private:
  using Create = int (__cdecl *)(const unsigned char*, std::size_t, void**);
  using ProcessFn = int (__cdecl *)(void*, const float*, float*, std::size_t);
  using Free = int (__cdecl *)(void*);
  std::unique_ptr<VerifiedFile> model_;
  VerifiedModule module_;
  std::string model_path_;
  Create create_ = nullptr;
  ProcessFn process_ = nullptr;
  Free free_ = nullptr;
  void* state_ = nullptr;
};
}  // namespace boohta::deepfilter
#endif
