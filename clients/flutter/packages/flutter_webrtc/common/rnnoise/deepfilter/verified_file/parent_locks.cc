#include "parent_locks.h"
namespace boohta::deepfilter {
namespace {
bool Separator(wchar_t c) { return c == L'\\' || c == L'/'; }
bool Component(const std::wstring& path, size_t start, size_t end) {
  if (end <= start || path[end - 1] == L'.' || path[end - 1] == L' ') return false;
  for (size_t i = start; i < end; ++i) {
    if (path[i] == L':' || path[i] < 32) return false;
  }
  return true;
}
}
ParentLocks::~ParentLocks() {
  for (auto it = handles_.rbegin(); it != handles_.rend(); ++it) CloseHandle(*it);
}
bool ParentLocks::Open(const std::wstring& path) {
  if (!handles_.empty() || path.size() < 4 || path[1] != L':' || !Separator(path[2]) ||
      !((path[0] >= L'A' && path[0] <= L'Z') || (path[0] >= L'a' && path[0] <= L'z'))) return false;
  size_t start = 3;
  for (size_t i = start; i <= path.size(); ++i) {
    if (i == path.size() || Separator(path[i])) {
      if (!Component(path, start, i)) return false;
      start = i + 1;
    }
  }
  auto lock = [this](const std::wstring& dir) {
    HANDLE h = CreateFileW(dir.c_str(), FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
                           nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (h == INVALID_HANDLE_VALUE) return false;
    FILE_ATTRIBUTE_TAG_INFO info{};
    if (!GetFileInformationByHandleEx(h, FileAttributeTagInfo, &info, sizeof(info)) ||
        !(info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) || (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
      CloseHandle(h); return false;
    }
    handles_.push_back(h);
    return true;
  };
  if (!lock(path.substr(0, 3))) return false;
  for (size_t i = 3; i < path.size(); ++i) {
    if (Separator(path[i]) && !lock(path.substr(0, i))) return false;
  }
  return true;
}
}
