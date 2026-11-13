#include "verified_file.h"
#include <cassert>
#include <cstdio>
#include <string>

using boohta::deepfilter::VerifiedFile;
void TestParentLock(const char* hash) {
  wchar_t root[MAX_PATH]{}, path[MAX_PATH]{};
  assert(GetTempPathW(MAX_PATH, root));
  assert(GetTempFileNameW(root, L"dfp", 0, path));
  assert(DeleteFileW(path));
  assert(CreateDirectoryW(path, nullptr));
  const std::wstring dir(path), file = dir + L"\\model.bin", moved = dir + L"-moved";
  HANDLE out = CreateFileW(file.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, 0, nullptr);
  assert(out != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  assert(WriteFile(out, "abc", 3, &written, nullptr) && written == 3);
  assert(CloseHandle(out));
  {
    VerifiedFile bad;
    assert(!bad.Open(dir + L"\\..\\" + dir.substr(dir.find_last_of(L"\\/") + 1) + L"\\model.bin", hash, 3));
  }
  const std::wstring link = dir + L"-link";
  if (CreateSymbolicLinkW(link.c_str(), dir.c_str(), SYMBOLIC_LINK_FLAG_DIRECTORY | 2)) {
    VerifiedFile unsafe;
    assert(!unsafe.Open(link + L"\\model.bin", hash, 3));
    assert(RemoveDirectoryW(link.c_str()));
  } else {
    std::puts("SKIP: symbolic link creation unavailable on this machine");
  }
  {
    VerifiedFile valid;
    assert(valid.Open(file, hash, 3));
    assert(!MoveFileW(dir.c_str(), moved.c_str()));
  }
  assert(MoveFileW(dir.c_str(), moved.c_str()));
  assert(DeleteFileW((moved + L"\\model.bin").c_str()));
  assert(RemoveDirectoryW(moved.c_str()));
}
int main() {
  wchar_t directory[MAX_PATH]{}, temporary[MAX_PATH]{};
  assert(GetTempPathW(MAX_PATH, directory) > 0);
  assert(GetTempFileNameW(directory, L"dfn", 0, temporary));
  const std::wstring unicode = std::wstring(temporary) + L"-\u0437\u0432\u0443\u043a";
  assert(MoveFileW(temporary, unicode.c_str()));
  HANDLE output = CreateFileW(unicode.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  assert(output != INVALID_HANDLE_VALUE);
  DWORD written = 0;
  assert(WriteFile(output, "abc", 3, &written, nullptr) && written == 3);
  assert(CloseHandle(output));
  const char* hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
  {
    VerifiedFile valid;
    assert(valid.Open(unicode, hash, 3));
    HANDLE overwrite = CreateFileW(unicode.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
    assert(overwrite == INVALID_HANDLE_VALUE);
    assert(!DeleteFileW(unicode.c_str()));
    assert(!valid.Open(unicode, hash, 3));
  }
  {
    VerifiedFile bad;
    assert(!bad.Open(unicode, "0000000000000000000000000000000000000000000000000000000000000000", 3));
    assert(!bad.Open(unicode, hash, 2));
    assert(!bad.Open(L"relative.txt", hash, 3));
    assert(!bad.Open(unicode, "invalid", 3));
  }
  assert(DeleteFileW(unicode.c_str()));
  TestParentLock(hash);
}
