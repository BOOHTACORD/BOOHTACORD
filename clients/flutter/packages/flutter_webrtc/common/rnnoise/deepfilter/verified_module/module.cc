#include "module.h"

namespace boohta::deepfilter {
VerifiedModule::~VerifiedModule() { if (module_) FreeLibrary(module_); }
bool VerifiedModule::Open(const std::wstring& path, const char* sha256, std::uint64_t max_bytes) {
  if (module_) return false;
  auto file = std::make_unique<VerifiedFile>();
  if (!file->Open(path, sha256, max_bytes)) return false;
  HMODULE module = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!module) return false;
  file_ = std::move(file);
  module_ = module;
  return true;
}
FARPROC VerifiedModule::Symbol(const char* name) const noexcept {
  return module_ && name ? GetProcAddress(module_, name) : nullptr;
}
}  // namespace boohta::deepfilter
