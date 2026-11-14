#include "engine.h"
#include <algorithm>
#include <chrono>
#include "../preflight/benchmark.h"

namespace boohta::deepfilter {
namespace {
bool Utf8Path(const std::wstring& input, std::string& output) {
  if (input.empty() || input.size() > 32768) return false;
  const auto length = static_cast<int>(input.size());
  const int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, input.data(), length, nullptr, 0, nullptr, nullptr);
  if (bytes <= 0 || bytes > 32768) return false;
  output.resize(bytes);
  return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, input.data(), length,
                             output.data(), bytes, nullptr, nullptr) == bytes;
}
}  // namespace
VerifiedEngine::~VerifiedEngine() { Close(); }
bool VerifiedEngine::Open(const std::wstring& dll, const char* dll_hash,
                          const std::wstring& model, const char* model_hash) {
  if (model_ || create_) return false;
  std::string path;
  if (!Utf8Path(model, path)) return false;
  auto file = std::make_unique<VerifiedFile>();
  if (!file->Open(model, model_hash, 64 * 1024 * 1024) ||
      !module_.Open(dll, dll_hash, 128 * 1024 * 1024)) return false;
  auto create = reinterpret_cast<Create>(module_.Symbol("research_create"));
  auto process = reinterpret_cast<ProcessFn>(module_.Symbol("research_process"));
  auto release = reinterpret_cast<Free>(module_.Symbol("research_free"));
  if (!create || !process || !release) return false;
  model_path_ = std::move(path); model_ = std::move(file);
  create_ = create; process_ = process; free_ = release;
  return true;
}
bool VerifiedEngine::Reset() {
  if (!create_ || !Close()) return false;
  if (!CreateState()) return false;
  if (!preflight_passed_) {
    const auto result = RunPreflight([this](AudioFrame& frame) { return Process(frame); }, [] {
      return std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now().time_since_epoch()).count();
    });
    preflight_p95_us_.store(result.p95_us); preflight_max_us_.store(result.max_us);
    if (!result.ready) { Close(); return false; }
    // Discard synthetic model history before admitting captured audio.
    if (!Close() || !CreateState()) return false;
    preflight_passed_ = true;
  }
  return true;
}
bool VerifiedEngine::CreateState() {
  void* state = nullptr;
  if (create_(reinterpret_cast<const unsigned char*>(model_path_.data()), model_path_.size(), &state) != 0 || !state)
    return false;
  state_ = state;
  return true;
}
bool VerifiedEngine::Process(AudioFrame& frame) {
  if (!state_ || !process_) return false;
  float output[480]{};
  if (process_(state_, frame.samples.data(), output, 480) != 0) return false;
  std::copy_n(output, 480, frame.samples.data());
  return true;
}
bool VerifiedEngine::Close() {
  if (!state_) return true;
  void* state = state_; state_ = nullptr;
  return free_ && free_(state) == 0;
}
}  // namespace boohta::deepfilter
