#ifndef BOOHTA_DEEPFILTER_PARENT_LOCKS_H_
#define BOOHTA_DEEPFILTER_PARENT_LOCKS_H_
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <string>
#include <vector>
namespace boohta::deepfilter {
// Control-thread guard: hold each ancestor without delete sharing until the
// verified file and its consumers are finished. Ambiguous components are rejected.
class ParentLocks {
 public:
  ~ParentLocks();
  ParentLocks() = default;
  ParentLocks(const ParentLocks&) = delete;
  ParentLocks& operator=(const ParentLocks&) = delete;
  bool Open(const std::wstring& path);
 private:
  std::vector<HANDLE> handles_;
};
}
#endif
