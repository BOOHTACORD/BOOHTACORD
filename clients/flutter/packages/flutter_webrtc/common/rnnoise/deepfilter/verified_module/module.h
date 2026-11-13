#ifndef BOOHTA_DEEPFILTER_VERIFIED_MODULE_H_
#define BOOHTA_DEEPFILTER_VERIFIED_MODULE_H_
#include "../verified_file/verified_file.h"
#include <memory>

namespace boohta::deepfilter {
// Load only an explicitly pinned absolute local file, while retaining the
// verified file lock. Dependencies are resolved from Windows System32 only.
// This does not authenticate ancestor directories or prevent their replacement
// between verification and LoadLibraryEx. Do not treat it as a release trust
// boundary until the owner establishes a trusted, stable installation path.
class VerifiedModule {
 public:
  VerifiedModule() = default;
  ~VerifiedModule();
  VerifiedModule(const VerifiedModule&) = delete;
  VerifiedModule& operator=(const VerifiedModule&) = delete;
  bool Open(const std::wstring& path, const char* sha256, std::uint64_t max_bytes);
  FARPROC Symbol(const char* name) const noexcept;
 private:
  std::unique_ptr<VerifiedFile> file_;
  HMODULE module_ = nullptr;
};
}  // namespace boohta::deepfilter
#endif
