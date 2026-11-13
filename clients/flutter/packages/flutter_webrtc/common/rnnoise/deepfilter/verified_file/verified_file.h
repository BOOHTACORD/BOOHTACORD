#ifndef BOOHTA_DEEPFILTER_VERIFIED_FILE_H_
#define BOOHTA_DEEPFILTER_VERIFIED_FILE_H_
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include "parent_locks.h"
#include <memory>
#include <cstdint>
#include <string>

namespace boohta::deepfilter {
// Keeps the verified file open without write/delete sharing. Control thread
// only; destroy after all consumers have finished reading the file.
class VerifiedFile {
 public:
  VerifiedFile() = default;
  ~VerifiedFile();
  VerifiedFile(const VerifiedFile&) = delete;
  VerifiedFile& operator=(const VerifiedFile&) = delete;
  bool Open(const std::wstring& path, const char* sha256, std::uint64_t max_bytes);
 private:
  HANDLE handle_ = INVALID_HANDLE_VALUE;
  std::unique_ptr<ParentLocks> parents_;
};
}  // namespace boohta::deepfilter
#endif
