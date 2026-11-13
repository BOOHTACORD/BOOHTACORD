#include "experimental_deepfilter.h"
#include "deepfilter/owner/owner.h"
#include <windows.h>
#include <string>
namespace flutter_webrtc_plugin {
class ExperimentalDeepFilter::Impl {
 public:
  boohta::deepfilter::ExperimentalOwner owner;
};
ExperimentalDeepFilter::ExperimentalDeepFilter() : impl_(std::make_unique<Impl>()) {}
ExperimentalDeepFilter::~ExperimentalDeepFilter() = default;
boohta::deepfilter::CaptureHook* ExperimentalDeepFilter::hook() const noexcept {
  return impl_->owner.hook();
}
bool ExperimentalDeepFilter::Open() {
  wchar_t path[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, path, 32768);
  if (!length || length >= 32768) return false;
  std::wstring directory(path, length);
  const auto separator = directory.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return false;
  directory.resize(separator + 1);
  return impl_->owner.Open(directory + L"boohta_deepfilter.dll", BOOHTA_DEEPFILTER_DLL_SHA256,
                           directory + L"boohta_deepfilter_model.tar.gz", BOOHTA_DEEPFILTER_MODEL_SHA256);
}
std::unique_ptr<ExperimentalDeepFilter> OpenExperimentalDeepFilter() {
  auto owner = std::make_unique<ExperimentalDeepFilter>();
  if (!owner->Open()) return nullptr;
  return owner;
}
}
